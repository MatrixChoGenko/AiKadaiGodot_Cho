extends GutTest
## アーキテクチャ門番テスト（Architecture §18.4）。
## 前半：検査器そのものが違反を検出できること（わざと違反させたソースで失敗すること）。
## 後半：実際の ②③④ 層のソースに違反が無いこと。

var _scanner: LayerRuleScanner


func before_each() -> void:
	_scanner = LayerRuleScanner.new()


func _assert_flags(source: String, rule: String) -> void:
	var found := _scanner.scan_source(source)
	assert_eq(found.size(), 1, "should flag [%s]: %s" % [rule, source])
	if found.size() == 1:
		assert_string_contains(found[0], "[%s]" % rule)


func _assert_clean(source: String) -> void:
	var found := _scanner.scan_source(source)
	assert_eq(found.size(), 0, "should NOT flag: %s -> %s" % [source, ", ".join(found)])


# —— 検査器の正例（違反を検出する）——

func test_flags_node_inheritance() -> void:
	_assert_flags("class_name Foo extends Node", "node_inheritance")
	_assert_flags("extends Control", "node_inheritance")
	_assert_flags("extends Node2D", "node_inheritance")


func test_flags_scene_tree_access() -> void:
	_assert_flags("\tvar t := get_tree()", "scene_tree")
	_assert_flags("\tget_node(\"X\")", "scene_tree")


func test_flags_await() -> void:
	_assert_flags("\tawait something.done", "await")


func test_flags_global_rng() -> void:
	_assert_flags("\tvar n := randi()", "global_rng")
	_assert_flags("\tvar f := randf_range(0.0, 1.0)", "global_rng")
	_assert_flags("\trandomize()", "global_rng")
	_assert_flags("\tseed(42)", "global_rng")


func test_flags_array_rng() -> void:
	_assert_flags("\tcards.shuffle()", "array_rng")
	_assert_flags("\tvar c = cards.pick_random()", "array_rng")


func test_flags_file_io() -> void:
	_assert_flags("\tvar f := FileAccess.open(p, FileAccess.READ)", "file_io")
	_assert_flags("\tvar r := load(\"res://x.tres\")", "file_io")


func test_flags_realtime() -> void:
	_assert_flags("\tvar t := Time.get_ticks_msec()", "realtime")
	_assert_flags("\tEngine.time_scale = 0.5", "realtime")


func test_flags_autoload_reference() -> void:
	var names := LayerRuleScanner.autoload_names()
	assert_eq(names.size(), 8, "autoloads: %s" % ", ".join(names))
	for n in names:
		_assert_flags("\t%s.do_something()" % n, "autoload")


# —— 検査器の負例（誤検出しない）——

func test_does_not_flag_rng_streams_api() -> void:
	_assert_clean("\trng.shuffle(&\"draw\", piles.draw)")
	_assert_clean("\tvar c = rng.pick(&\"reward\", pool)")
	_assert_clean("\tvar n := _gen.randi_range(0, 3)")
	_assert_clean("\tg.seed = 12")


func test_does_not_flag_comments_and_strings() -> void:
	_assert_clean("## await は使わない。randi() も get_tree() も禁止")
	_assert_clean("\tvar s := \"randi() await get_tree()\"  # extends Node")
	_assert_clean("\tvar s := 'Engine.time_scale'")


func test_does_not_flag_ordinary_identifiers() -> void:
	_assert_clean("class_name ContentLibrary extends Resource")
	_assert_clean("\tvar settings_value := run_settings.awaited_count")
	_assert_clean("\tvar node: MapNode = graph.node_at(3)")
	_assert_clean("class_name Combat extends RefCounted")


# —— 実ソースの検査 ——

func test_rule_layer_dirs_exist() -> void:
	for dir_path in LayerRuleScanner.RULE_DIRS:
		assert_true(DirAccess.dir_exists_absolute(dir_path), "missing dir %s" % dir_path)


func test_rule_layers_have_no_violations() -> void:
	var violations := PackedStringArray()
	var scanned := 0
	for dir_path in LayerRuleScanner.RULE_DIRS:
		scanned += LayerRuleScanner.list_scripts(dir_path).size()
		violations.append_array(_scanner.scan_dir(dir_path))
	gut.p("layer rule scan: %d scripts" % scanned)
	assert_eq(violations.size(), 0, "layer rule violations:\n" + "\n".join(violations))

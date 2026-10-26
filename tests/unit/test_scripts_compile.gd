extends GutTest
## すべてのスクリプトが読み込める（コンパイルエラーがない）こと。
## 一度も参照されないスクリプトのコンパイルエラーは実行時まで表に出ないので、ここで全部読み込んで検出する。

const DIRS: Array[String] = ["res://src", "res://addons/trycard_tools", "res://tests/support"]


func test_all_scripts_load() -> void:
	var count := 0
	for dir_path in DIRS:
		for path in LayerRuleScanner.list_scripts(dir_path):
			var script := load(path) as GDScript
			assert_not_null(script, "failed to load %s" % path)
			# コンパイルに失敗したスクリプトも load() では非 null が返るので、インスタンス化できるかで判定する。
			if script != null:
				assert_true(script.can_instantiate() or script.is_abstract(), "does not compile: %s" % path)
			count += 1
	gut.p("loaded %d scripts" % count)
	assert_gt(count, 100)


func test_content_service_loaded_library() -> void:
	var content := get_tree().root.get_node("Content")
	assert_not_null(content.get(&"library"), "Content.library is null")

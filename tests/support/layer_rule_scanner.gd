class_name LayerRuleScanner extends RefCounted
## テスト支援：アーキテクチャ門番（Architecture §18.4 / §21 ルール 3）。
## ②③④ 層（src/content, src/domain, src/flow）のソースに、SceneTree・await・グローバル乱数・
## ファイル I/O・実時間・Autoload への依存が無いことを検査する。
## コメントと文字列リテラルは取り除いてから照合するので、説明文に禁止語が出ても違反にならない。

const RULE_DIRS: Array[String] = ["res://src/content", "res://src/domain", "res://src/flow"]

var _rules: Array[Dictionary] = []   # { name: String, regex: RegEx }


func _init() -> void:
	_add(&"node_inheritance", "\\bextends\\s+(Node|Node2D|Node3D|Control|CanvasItem|CanvasLayer|Viewport|Window|SceneTree)\\b")
	_add(&"scene_tree", "\\b(get_tree|get_node|get_parent|get_viewport)\\s*\\(")
	_add(&"await", "\\bawait\\b")
	# グローバル乱数の関数呼び出し（メソッド呼び出し `x.randi()` は RandomNumberGenerator なので対象外）。
	_add(&"global_rng", "(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|seed)\\s*\\(")
	# 引数なしの Array.shuffle() / pick_random() はグローバル乱数。RngStreams.shuffle(stream, items) は引数があるので対象外。
	_add(&"array_rng", "\\.(shuffle|pick_random)\\s*\\(\\s*\\)")
	_add(&"file_io", "\\b(FileAccess|DirAccess|ResourceSaver|ResourceLoader|ConfigFile)\\b|(?<![\\w.])(load|preload)\\s*\\(")
	_add(&"realtime", "\\b(Time|OS|Engine)\\s*\\.")
	var names := autoload_names()
	if not names.is_empty():
		_add(&"autoload", "\\b(%s)\\s*\\." % "|".join(names))


## project.godot に登録されている Autoload 名。Autoload を追加すれば自動で監視対象になる。
static func autoload_names() -> PackedStringArray:
	var names := PackedStringArray()
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	return names


## ソース文字列を検査し、違反を "行番号 [規則] 行の内容" の形で返す。
func scan_source(source: String) -> PackedStringArray:
	var found := PackedStringArray()
	var lines := source.split("\n")
	for i in lines.size():
		var code := strip_comments_and_strings(lines[i])
		for rule: Dictionary in _rules:
			var regex: RegEx = rule["regex"]
			if regex.search(code) != null:
				found.append("%d [%s] %s" % [i + 1, rule["name"], lines[i].strip_edges()])
	return found


## ディレクトリ以下の .gd をすべて検査し、違反を "パス:行番号 [規則] 内容" の形で返す。
func scan_dir(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for path in list_scripts(dir_path):
		var source := FileAccess.get_file_as_string(path)
		for v in scan_source(source):
			found.append("%s:%s" % [path, v])
	return found


static func list_scripts(dir_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file in dir.get_files():
		if file.ends_with(".gd"):
			result.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		result.append_array(list_scripts(dir_path.path_join(sub)))
	return result


## 1 行から文字列リテラルの中身とコメントを取り除く（複数行文字列は対象外）。
static func strip_comments_and_strings(line: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote.is_empty():
			if c == "#":
				break
			if c == "\"" or c == "'":
				quote = c
			out += c
		else:
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
				out += c
		i += 1
	return out


func _add(name: StringName, pattern: String) -> void:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	assert(err == OK, "LayerRuleScanner: bad pattern for %s" % name)
	_rules.append({ "name": name, "regex": regex })

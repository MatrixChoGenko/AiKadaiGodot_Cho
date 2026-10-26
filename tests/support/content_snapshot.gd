class_name ContentSnapshot extends RefCounted
## テスト支援：コンテンツ Resource の中身を 1 つの文字列にする。戦闘の前後で比べて
## 「実行時にコンテンツが書き換えられていない」（Architecture §21 ルール 1）を検査する。


static func take(lib: ContentLibrary) -> String:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	var roots: Array = []
	for field: String in ["cards", "statuses", "keywords", "relics", "potions", "enemies", "encounters", "events", "acts"]:
		roots.append_array(lib.get(field))
	roots.append(lib.config)
	for res: Resource in roots:
		_visit(res, out, seen)
	return "\n".join(out)


static func _visit(res: Resource, out: PackedStringArray, seen: Dictionary) -> void:
	if res == null or seen.has(res):
		return
	seen[res] = true
	var line := PackedStringArray([str(res.get_instance_id())])
	var children: Array[Resource] = []
	for prop in res.get_property_list():
		var usage: int = prop["usage"]
		if not (usage & PROPERTY_USAGE_STORAGE and usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = res.get(prop["name"])
		line.append("%s=%s" % [prop["name"], _describe(value, children)])
	out.append(" ".join(line))
	for child in children:
		_visit(child, out, seen)


static func _describe(value: Variant, children: Array[Resource]) -> String:
	if value is Resource:
		children.append(value)
		return "#%d" % (value as Resource).get_instance_id()
	if value is Array:
		var parts := PackedStringArray()
		for item: Variant in value:
			parts.append(_describe(item, children))
		return "[%s]" % ",".join(parts)
	if value is Dictionary:
		var parts := PackedStringArray()
		for k: Variant in value:
			parts.append("%s:%s" % [_describe(k, children), _describe((value as Dictionary)[k], children)])
		return "{%s}" % ",".join(parts)
	return str(value)

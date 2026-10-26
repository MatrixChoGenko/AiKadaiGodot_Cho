@tool
class_name ValidationReport extends RefCounted
## ContentValidator の結果。errors が 0 件なら合格。

var errors: PackedStringArray = []
var warnings: PackedStringArray = []


func error(where: String, message: String) -> void:
	errors.append("%s: %s" % [where, message])


func warn(where: String, message: String) -> void:
	warnings.append("%s: %s" % [where, message])


func ok() -> bool:
	return errors.is_empty()


func _to_string() -> String:
	var lines := PackedStringArray()
	lines.append("ContentValidator: %d error(s), %d warning(s)" % [errors.size(), warnings.size()])
	for e in errors:
		lines.append("  ERROR " + e)
	for w in warnings:
		lines.append("  WARN  " + w)
	return "\n".join(lines)

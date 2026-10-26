extends Node
## ① Platform / Autoload `Log`：カテゴリ別ログ（combat / run / save …）。
## M0 では出力のみ。デバッグオーバーレイでの閲覧（Architecture §19）は後続で追加する。

enum Level { DEBUG, INFO, WARN, ERROR }

## 直近のログを保持する件数（デバッグオーバーレイ用）。
const HISTORY_LIMIT: int = 500

var min_level: Level = Level.DEBUG if OS.is_debug_build() else Level.INFO
var _history: Array[String] = []


func debug(category: StringName, message: String) -> void:
	_write(Level.DEBUG, category, message)


func info(category: StringName, message: String) -> void:
	_write(Level.INFO, category, message)


func warn(category: StringName, message: String) -> void:
	_write(Level.WARN, category, message)


func error(category: StringName, message: String) -> void:
	_write(Level.ERROR, category, message)


func history() -> Array[String]:
	return _history.duplicate()


func _write(level: Level, category: StringName, message: String) -> void:
	if level < min_level:
		return
	var line := "[%s][%s] %s" % [Level.keys()[level], category, message]
	_history.push_back(line)
	if _history.size() > HISTORY_LIMIT:
		_history.pop_front()
	match level:
		Level.WARN:
			push_warning(line)
		Level.ERROR:
			push_error(line)
		_:
			print(line)

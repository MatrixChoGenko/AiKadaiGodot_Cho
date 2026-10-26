class_name ScreenHost extends Control
## ⑤ Presentation：画面の入れ物。同時に 1 つの Screen だけを持つ（Architecture §13.1）。
## Control.show() と衝突するため、切り替えのメソッド名は show_screen() にしている。

signal screen_changed(screen: Screen)

## フェードの秒数。0 ならフェードしない（テスト用）。
@export var fade_seconds: float = 0.15

var current: Screen = null
## 背景として残している前の画面（戦闘 → 報酬で、暗くした戦場を報酬の後ろに見せる。無ければ null）。
## 次に画面を切り替えるときに current と一緒に破棄する。
var backdrop: Screen = null


## 旧画面を破棄し、新しい画面をインスタンス化して enter(args) を呼ぶ。
## 旧画面は入力を止めてからフェードアウトして解放する（待たずに戻る）。
## keep_backdrop なら旧画面は破棄せず、exit() と enter_backdrop() を呼んで新しい画面の後ろに残す。
func show_screen(scene: PackedScene, args: Dictionary = {}, keep_backdrop: bool = false) -> Screen:
	assert(scene != null, "ScreenHost.show_screen: scene is null")
	var next := scene.instantiate() as Screen
	assert(next != null, "ScreenHost.show_screen: root of %s is not a Screen" % scene.resource_path)
	_dismiss(backdrop, false)
	backdrop = null
	if keep_backdrop and current != null:
		backdrop = current
		backdrop.exit()
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.enter_backdrop()
	else:
		_dismiss(current)
	current = next
	add_child(next)
	next.enter(args)
	if fade_seconds > 0.0:
		next.modulate.a = 0.0
		next.create_tween().tween_property(next, "modulate:a", 1.0, fade_seconds)
	screen_changed.emit(next)
	return next


## call_exit = false：背景として残したとき exit() は呼び済み。
func _dismiss(old: Screen, call_exit: bool = true) -> void:
	if old == null:
		return
	if call_exit:
		old.exit()
	old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	old.process_mode = Node.PROCESS_MODE_DISABLED
	if fade_seconds > 0.0:
		# Tween は host 側に作る。旧画面は PROCESS_MODE_DISABLED にしたので、旧画面の Tween だと止まったまま解放されない。
		var tween := create_tween()
		tween.tween_property(old, "modulate:a", 0.0, fade_seconds)
		tween.tween_callback(old.queue_free)
	else:
		old.queue_free()

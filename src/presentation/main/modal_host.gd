class_name ModalHost extends Control
## ⑤ Presentation：スタック式のダイアログの入れ物（Architecture §13.1）。
## 画面切り替え時に Main が clear() を呼び、ダイアログの取り残しを防ぐ。

var _stack: Array[Modal] = []


func push(scene: PackedScene, args: Dictionary = {}) -> Modal:
	var modal := scene.instantiate() as Modal
	assert(modal != null, "ModalHost.push: root of %s is not a Modal" % scene.resource_path)
	_stack.push_back(modal)
	add_child(modal)
	modal.closed.connect(_on_modal_closed.bind(modal), CONNECT_ONE_SHOT)
	modal.enter(args)
	return modal


## 一番上のダイアログを閉じる。
func pop() -> void:
	if not _stack.is_empty():
		_remove(top())


func clear() -> void:
	while not _stack.is_empty():
		_remove(top())


func is_empty() -> bool:
	return _stack.is_empty()


func top() -> Modal:
	return null if _stack.is_empty() else _stack.back()


func _unhandled_input(event: InputEvent) -> void:
	if _stack.is_empty() or not event.is_action_pressed(&"ui_cancel"):
		return
	top().cancel()
	get_viewport().set_input_as_handled()


func _remove(modal: Modal) -> void:
	_stack.erase(modal)
	if modal.closed.is_connected(_on_modal_closed):
		modal.closed.disconnect(_on_modal_closed)
	modal.queue_free()


func _on_modal_closed(modal: Modal) -> void:
	_remove(modal)

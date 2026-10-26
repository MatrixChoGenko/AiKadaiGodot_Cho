class_name RestTile extends Control
## ⑤ Presentation：休憩所の選択肢のタイル 1 枚（StS2 の「Rest」「Smith」）。絵の下に名前。ホバーで金の縁が出て少し大きくなる。
## 選べないときは暗くし、ホバーしても大きくならない（説明は画面が出す）。

signal pressed
signal hover_changed(hovered: bool)

const FRAME: Texture2D = preload("res://assets/textures/ui/rest/tile_frame.png")
const FONT: Font = preload("res://assets/fonts/banner_mincho.ttf")
const TILE_SIZE: Vector2 = Vector2(300, 200)
const NAME_HEIGHT: float = 56.0
const HOVER_SCALE: float = 1.06
const DISABLED_COLOR: Color = Color(0.42, 0.42, 0.45)

var disabled: bool = false

var _frame: TextureRect
var _name: Label


func _init(art: Texture2D, title: String, enabled: bool = true) -> void:
	disabled = not enabled
	custom_minimum_size = Vector2(TILE_SIZE.x, TILE_SIZE.y + NAME_HEIGHT)
	size = custom_minimum_size
	pivot_offset = TILE_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	var pic := TextureRect.new()
	pic.texture = art
	pic.size = TILE_SIZE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pic)
	_frame = TextureRect.new()
	_frame.texture = FRAME
	_frame.size = TILE_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	add_child(_frame)
	_name = Label.new()
	_name.text = title
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.position = Vector2(0, TILE_SIZE.y + 4)
	_name.size = Vector2(TILE_SIZE.x, NAME_HEIGHT - 4)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_font_override(&"font", FONT)
	_name.add_theme_font_size_override(&"font_size", 36)
	_name.add_theme_color_override(&"font_color", Color(0.98, 0.86, 0.55))
	_name.add_theme_constant_override(&"outline_size", 8)
	_name.add_theme_color_override(&"font_outline_color", Color(0.12, 0.07, 0.03))
	add_child(_name)
	if disabled:
		modulate = DISABLED_COLOR
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func title_text() -> String:
	return _name.text


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not disabled:
		accept_event()
		pressed.emit()


func _set_hover(on: bool) -> void:
	hover_changed.emit(on)
	if disabled:
		return
	_frame.visible = on
	create_tween().tween_property(self, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), 0.08 if on else 0.14) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

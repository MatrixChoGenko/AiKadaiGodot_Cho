class_name EventOptionButton extends PanelContainer
## ⑤ Presentation：イベントの選択肢 1 つ（StS2 のイベント画面の、両端のとがった青緑の帯）。
## 1 行目 = 名前（金色）、2 行目 = 効果（BBCode。UiText.event_detail_markup で色付け）。選べないときは灰色にし、理由を赤みの行で出す。
## Button は子の大きさで伸びないので PanelContainer にし、クリックとホバーは自前で扱う。高さは文の行数に合わせて伸びる（帯の画像は 9 分割）。
## ホバーで縁が光り、少し大きくなる。

signal pressed

const TEX: Texture2D = preload("res://assets/textures/ui/reward/event_option.png")
const TEX_HOVER: Texture2D = preload("res://assets/textures/ui/reward/event_option_hover.png")
const TEX_DISABLED: Texture2D = preload("res://assets/textures/ui/reward/event_option_disabled.png")
const MIN_HEIGHT: float = 84.0
## 文の左右（とがった端の内側）と上下の余白：左・上・右・下。
const PAD: Vector4 = Vector4(58, 14, 46, 16)
const TITLE_COLOR: Color = Color(0.96, 0.79, 0.38)
const DETAIL_COLOR: Color = Color(0.93, 0.93, 0.9)
const HINT_COLOR: String = "#d9867a"
const DISABLED_COLOR: Color = Color(0.6, 0.6, 0.62)
const HOVER_SCALE: float = 1.025

var disabled: bool = false

var _title: Label
var _detail: RichTextLabel
var _styles: Dictionary[StringName, StyleBoxTexture] = {}


func _init(title: String, detail_bbcode: String, hint: String = "", enabled: bool = true) -> void:
	disabled = not enabled
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	for key: StringName in [&"normal", &"hover", &"disabled"]:
		_styles[key] = _style({&"normal": TEX, &"hover": TEX_HOVER, &"disabled": TEX_DISABLED}[key])
	_apply_style(&"disabled" if disabled else &"normal")
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 2)
	add_child(box)
	_title = Label.new()
	_title.text = title
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_size_override(&"font_size", 27)
	_title.add_theme_color_override(&"font_color", TITLE_COLOR if enabled else DISABLED_COLOR)
	_title.add_theme_constant_override(&"outline_size", 5)
	_title.add_theme_color_override(&"font_outline_color", Color(0.04, 0.06, 0.08))
	box.add_child(_title)
	var text := detail_bbcode
	if not enabled and not hint.is_empty():
		text += ("\n" if not text.is_empty() else "") + "[color=%s]%s[/color]" % [HINT_COLOR, hint]
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.scroll_active = false
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_theme_font_size_override(&"normal_font_size", 22)
	_detail.add_theme_color_override(&"default_color", DETAIL_COLOR if enabled else DISABLED_COLOR)
	_detail.text = text
	_detail.visible = not text.is_empty()
	box.add_child(_detail)


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func title_text() -> String:
	return _title.text


## 効果の行の文（色付けを除いた文字。テスト用）。
func detail_text() -> String:
	return _detail.get_parsed_text()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not disabled:
		accept_event()
		pressed.emit()


func _set_hover(on: bool) -> void:
	if disabled:
		return
	_apply_style(&"hover" if on else &"normal")
	create_tween().tween_property(self, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), 0.08 if on else 0.14) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_style(key: StringName) -> void:
	add_theme_stylebox_override(&"panel", _styles[key])


static func _style(tex: Texture2D) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = 40
	s.texture_margin_right = 40
	s.texture_margin_top = 22
	s.texture_margin_bottom = 22
	s.content_margin_left = PAD.x
	s.content_margin_top = PAD.y
	s.content_margin_right = PAD.z
	s.content_margin_bottom = PAD.w
	return s

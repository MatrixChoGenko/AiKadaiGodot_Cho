class_name ProceedArrow extends TextureButton
## ⑤ Presentation：画面の右下の赤い矢印（StS2 の「Proceed / Skip」）。報酬画面と休憩所で使う。
## 画面の右下に固定（アンカー）し、slide_in() で右から行き過ぎて戻る動きで滑り込む。ホバーで少し大きく明るくなる。

const ARROW: Texture2D = preload("res://assets/textures/ui/reward/arrow.png")
const FONT: Font = preload("res://assets/fonts/banner_mincho.ttf")
## 画面の右端・下端からの距離（px）と、滑り込む量。
const MARGIN: Vector2 = Vector2(60, 70)
const SLIDE: float = 260.0

var _label: Label


func _init(text: String = "進む") -> void:
	texture_normal = ARROW
	focus_mode = Control.FOCUS_NONE
	var s := ARROW.get_size()
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	_place(0.0)
	pivot_offset = s / 2.0
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override(&"font", FONT)
	_label.add_theme_font_size_override(&"font_size", 40)
	_label.add_theme_color_override(&"font_color", Color(1.0, 0.97, 0.88))
	_label.add_theme_constant_override(&"outline_size", 10)
	_label.add_theme_color_override(&"font_outline_color", Color(0.22, 0.12, 0.06))
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_right = -s.x * 0.12
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))


func set_label(text: String) -> void:
	_label.text = text


func label_text() -> String:
	return _label.text


## delay 秒後に右から滑り込む。
func slide_in(delay: float = 0.0) -> void:
	_place(SLIDE)
	create_tween().tween_method(_place, SLIDE, 0.0, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## x = 本来の位置から右へずらす量（px）。
func _place(x: float) -> void:
	var s := ARROW.get_size()
	offset_left = -MARGIN.x - s.x + x
	offset_right = -MARGIN.x + x
	offset_top = -MARGIN.y - s.y
	offset_bottom = -MARGIN.y


func _hover(on: bool) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE * (1.06 if on else 1.0), 0.1)
	t.tween_property(self, "self_modulate", Color(1.15, 1.15, 1.15) if on else Color.WHITE, 0.1)

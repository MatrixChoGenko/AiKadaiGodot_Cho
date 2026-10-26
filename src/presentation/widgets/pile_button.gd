class_name PileButton extends TipButton
## ⑤ Presentation：枚数のバッジ付きの画像ボタン（戦闘の山札・捨て札・廃棄、上部バーのデッキ。StS2 の HUD に合わせた）。
## 画像は icon（大きさいっぱいに縮める）、枚数は右下の赤い丸。名前はツールチップ（tooltip_text）に出す。
## ホバーで少し大きくなる。

const HOVER_SCALE: float = 1.08

## 表示する枚数（-1 = バッジを出さない）。
@export var count: int = 0:
	set(value):
		count = value
		queue_redraw()
## バッジの中心（大きさに対する比）と半径（px）。
@export var badge_at: Vector2 = Vector2(0.74, 0.76)
@export var badge_radius: float = 20.0
@export var badge_color: Color = Color(0.78, 0.12, 0.12)

var _hover_tween: Tween


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# flat でも押したときなどに描かれる枠を消す。
	for s: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func count_text() -> String:
	return str(count) if count >= 0 else ""


func _draw() -> void:
	if count < 0:
		return
	var c := size * badge_at
	draw_circle(c, badge_radius + 2.5, Color(0.08, 0.04, 0.04))
	draw_circle(c, badge_radius, badge_color)
	draw_circle(c + Vector2(0, -badge_radius * 0.35), badge_radius * 0.55, Color(1, 1, 1, 0.12))
	var font := get_theme_default_font()
	var fs := roundi(badge_radius * (1.2 if count < 10 else 1.0))
	var text := count_text()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := c + Vector2(-w / 2.0, font.get_ascent(fs) / 2.0 - font.get_descent(fs) / 2.0)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.1, 0.02, 0.02))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _set_hover(on: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	pivot_offset = size / 2.0
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), 0.1)

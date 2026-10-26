@tool
class_name GlyphBadge extends Control
## ⑤ Presentation：図形 ＋ 文字のアイコン（素材なしの方針。DevelopmentPlan 未決 #7 の回答「図形＋文字」）。
## マップノード / インテント / ステータス / レリック / ポーション / コストの宝石に使う。表示だけで、ルールは知らない。

enum Shape { CIRCLE, ROUNDED, DIAMOND }

## 画像の大きさ（大きさに対する比）の既定値。
const ICON_RATIO: float = 0.8

@export var text: String = "":
	set(value):
		text = value
		queue_redraw()
@export var fill: Color = Color(0.3, 0.3, 0.36):
	set(value):
		fill = value
		queue_redraw()
@export var outline: Color = Color(0, 0, 0, 0.8):
	set(value):
		outline = value
		queue_redraw()
@export var text_color: Color = Color.WHITE:
	set(value):
		text_color = value
		queue_redraw()
@export var shape: Shape = Shape.CIRCLE:
	set(value):
		shape = value
		queue_redraw()
## 0 = 大きさから自動で決める。
@export var font_size: int = 0:
	set(value):
		font_size = value
		queue_redraw()
@export var outline_width: float = 3.0:
	set(value):
		outline_width = value
		queue_redraw()
## 画像があれば図形の塗りと文字の代わりに描く（縁取りは outline_width > 0 のときだけ円で描く）。
@export var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
## 画像の大きさ（大きさに対する比）。
@export var icon_ratio: float = ICON_RATIO:
	set(value):
		icon_ratio = value
		queue_redraw()
## 画像の右下に重ねる小さな文字（ステータスの層数など）。画像のときだけ描く。
@export var corner_text: String = "":
	set(value):
		corner_text = value
		queue_redraw()


func setup(p_text: String, p_fill: Color, p_shape: Shape = Shape.CIRCLE) -> GlyphBadge:
	text = p_text
	fill = p_fill
	shape = p_shape
	return self


## tooltip_text（「見出し\n本文」）を共通のツールチップの見た目で出す（U11）。
func _make_custom_tooltip(for_text: String) -> Object:
	return TooltipPanel.for_tooltip(for_text)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := size / 2.0
	if icon != null:
		_draw_icon(c)
		return
	match shape:
		Shape.CIRCLE:
			var radius := minf(size.x, size.y) / 2.0 - outline_width / 2.0
			draw_circle(c, radius, fill)
			if outline_width > 0.0:
				draw_arc(c, radius, 0.0, TAU, 48, outline, outline_width, true)
		Shape.DIAMOND:
			var pts := PackedVector2Array([Vector2(c.x, 0), Vector2(size.x, c.y), Vector2(c.x, size.y), Vector2(0, c.y)])
			draw_colored_polygon(pts, fill)
			if outline_width > 0.0:
				pts.append(pts[0])
				draw_polyline(pts, outline, outline_width, true)
		_:
			var box := StyleBoxFlat.new()
			box.bg_color = fill
			box.set_corner_radius_all(int(minf(size.x, size.y) * 0.25))
			box.set_border_width_all(int(outline_width))
			box.border_color = outline
			draw_style_box(box, r)
	if text.is_empty():
		return
	var font := get_theme_default_font()
	var fs := font_size if font_size > 0 else maxi(10, int(minf(size.y * 0.5, size.x * 0.9 / maxf(1.0, text.length() * 0.9))))
	var line := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(c.x - line.x / 2.0, c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)


func _draw_icon(c: Vector2) -> void:
	if outline_width > 0.0:
		var radius := minf(size.x, size.y) / 2.0 - outline_width / 2.0
		draw_arc(c, radius, 0.0, TAU, 48, outline, outline_width, true)
	var tex := icon.get_size()
	var fit := minf(size.x, size.y) * icon_ratio / maxf(tex.x, tex.y)
	var s := tex * fit
	draw_texture_rect(icon, Rect2(c - s / 2.0, s), false)
	if corner_text.is_empty():
		return
	var font := get_theme_default_font()
	var fs := font_size if font_size > 0 else maxi(10, int(size.y * 0.45))
	var line := font.get_string_size(corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(size.x - line.x + 2.0, size.y + 2.0 - font.get_descent(fs))
	draw_string_outline(font, pos, corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
	draw_string(font, pos, corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

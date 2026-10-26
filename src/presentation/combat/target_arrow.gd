class_name TargetArrow extends Control
## ⑤ Presentation：照準の矢印（GameDesign §15.4）。カードからマウスへの曲線を、等間隔の丸（先へ行くほど大きい）と
## 矢じりで描く。丸は根元から先へ流れる。全面に置き、入力は受けない。

const COLOR_IDLE: Color = Color(1, 1, 1, 0.9)
const COLOR_LOCKED: Color = Color(1.0, 0.42, 0.3, 1.0)
const COLOR_EDGE: Color = Color(0, 0, 0, 0.65)
## 曲線を測るための分割数（節の数ではない）。
const SAMPLES: int = 48
const SPACING: float = 24.0
const SIZE_MIN: float = 4.0
const SIZE_MAX: float = 9.0
const FLOW_SPEED: float = 70.0
const HEAD_LENGTH: float = 40.0
const HEAD_HALF_WIDTH: float = 24.0
const EDGE: float = 3.0

var from_global: Vector2 = Vector2.ZERO
var to_global: Vector2 = Vector2.ZERO
## 敵の上にあるときは色を変える。
var locked: bool = false

var _flow: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func point(from: Vector2, to: Vector2, on_target: bool) -> void:
	from_global = from
	to_global = to
	locked = on_target
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_flow = fmod(_flow + delta * FLOW_SPEED, SPACING)
	queue_redraw()


func _draw() -> void:
	var a := from_global - global_position
	var b := to_global - global_position
	var ctrl := Vector2((a.x + b.x) / 2.0, minf(a.y, b.y) - 160.0)
	var pts := PackedVector2Array()
	var dist := PackedFloat32Array()
	for i in SAMPLES + 1:
		var t := float(i) / SAMPLES
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
		dist.append(0.0 if i == 0 else dist[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := dist[SAMPLES]
	var color := COLOR_LOCKED if locked else COLOR_IDLE
	var dir := (pts[SAMPLES] - pts[SAMPLES - 2]).normalized()
	# 節は矢じりの手前まで。根元に近いほど小さく薄い。
	var end := total - HEAD_LENGTH * 0.8
	var d := _flow
	var k := 1
	while d < end:
		while k < SAMPLES and dist[k] < d:
			k += 1
		var f := (d - dist[k - 1]) / maxf(dist[k] - dist[k - 1], 0.001)
		var p := pts[k - 1].lerp(pts[k], f)
		var u := d / maxf(total, 1.0)
		var c := color
		c.a *= lerpf(0.35, 1.0, minf(u * 2.0, 1.0))
		var edge := COLOR_EDGE
		edge.a *= c.a
		var r := lerpf(SIZE_MIN, SIZE_MAX, u)
		draw_circle(p, r + EDGE, edge, true, -1.0, true)
		draw_circle(p, r, c, true, -1.0, true)
		d += SPACING
	_draw_head(b, dir, color)


func _draw_head(tip: Vector2, dir: Vector2, c: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var back := tip - dir * HEAD_LENGTH
	var head := PackedVector2Array([tip + dir * 6.0, back + side * HEAD_HALF_WIDTH, back + dir * 10.0, back - side * HEAD_HALF_WIDTH])
	var outer := PackedVector2Array()
	var center := tip - dir * HEAD_LENGTH * 0.5
	for q in head:
		outer.append(center + (q - center) * 1.15)
	draw_colored_polygon(outer, COLOR_EDGE)
	draw_colored_polygon(head, c)

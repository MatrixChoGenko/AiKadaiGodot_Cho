class_name TargetRings extends Control
## ⑤ Presentation：照準が付いたユニットの足元の光る楕円（GameDesign §15.4）。Field の 3D の舞台の下に置くので、
## リングの中央は足で隠れる。カメラが真横なので地面の円は楕円（縦を潰す）で描く。入力は受けない。

const COLOR: Color = Color(1, 1, 1)
## 楕円の横幅 = 立ち絵の矩形の幅 × これ。縦 = 横 × FLATTEN。
const WIDTH_RATIO: float = 0.8
const FLATTEN: float = 0.22
const LINE_WIDTH: float = 4.0
## ぼかしの層（外へ広がるほど薄く）。
const GLOW_LAYERS: int = 4
const GLOW_STEP: float = 4.0
const FILL_ALPHA: float = 0.16
const POINTS: int = 64
const PULSE_SECONDS: float = 0.9
const PULSE_SCALE: float = 0.06

var _views: Array[UnitView] = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func watch(view: UnitView) -> void:
	view.targeted_changed.connect(_on_targeted_changed)


func ring_count() -> int:
	return _views.size()


func _on_targeted_changed(view: UnitView, on: bool) -> void:
	if on and not _views.has(view):
		_views.append(view)
	elif not on:
		_views.erase(view)
	set_process(not _views.is_empty())
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + PULSE_SCALE * sin(_time * TAU / PULSE_SECONDS)
	for v in _views:
		if not is_instance_valid(v):
			continue
		var rect := v.portrait_rect()
		var center := get_global_transform().affine_inverse() * BattleStage.foot_of(rect)
		var radius := rect.size.x * WIDTH_RATIO / 2.0 * pulse
		var pts := PackedVector2Array()
		for i in POINTS + 1:
			var a := TAU * i / POINTS
			pts.append(center + Vector2(cos(a) * radius, sin(a) * radius * FLATTEN))
		var fill := COLOR
		fill.a = FILL_ALPHA
		draw_colored_polygon(pts.slice(0, POINTS), fill)
		for i in range(GLOW_LAYERS, 0, -1):
			var glow := COLOR
			glow.a = 0.14 * (GLOW_LAYERS - i + 1) / GLOW_LAYERS
			draw_polyline(pts, glow, LINE_WIDTH + GLOW_STEP * i, true)
		draw_polyline(pts, COLOR, LINE_WIDTH, true)

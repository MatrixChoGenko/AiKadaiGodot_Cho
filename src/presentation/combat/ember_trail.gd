class_name EmberTrail extends Line2D
## ⑤ Presentation：ターン終了で捨て札へ飛ぶカードの炎の尾（StS2 の録画に合わせた）。
## 追う Control の中心を毎フレーム先頭に足し、古い点から消す。追う相手が消えたら尾を縮めきって自分も消える。
## 尾と先頭の火花（CPUParticles2D）は加算（色を抑えて白飛びさせない）。座標は top_level のキャンバス座標。

## 最初（太さ 30・16 点・明るい加算）は光りすぎ、通常合成で細く短くすると地味すぎたので、その中間（2026-10-20）。
const MAX_POINTS: int = 12
const WIDTH: float = 18.0

var _target: WeakRef
var _sparks: CPUParticles2D


static func follow(target: Control, parent: Node) -> EmberTrail:
	var trail := EmberTrail.new()
	trail._target = weakref(target)
	parent.add_child(trail)
	return trail


func _ready() -> void:
	top_level = true
	z_index = 110
	width = WIDTH
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	width_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.28, 0.05, 0.0))
	g.set_color(1, Color(1.0, 0.6, 0.25, 0.85))
	g.add_point(0.6, Color(1.0, 0.38, 0.08, 0.5))
	gradient = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_sparks = CPUParticles2D.new()
	_sparks.top_level = true
	_sparks.material = mat
	_sparks.amount = 16
	_sparks.lifetime = 0.45
	_sparks.local_coords = false
	_sparks.spread = 180.0
	_sparks.gravity = Vector2(0, 260)
	_sparks.initial_velocity_min = 30.0
	_sparks.initial_velocity_max = 110.0
	_sparks.scale_amount_min = 2.0
	_sparks.scale_amount_max = 3.0
	var sg := Gradient.new()
	sg.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	sg.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	_sparks.color_ramp = sg
	_sparks.emitting = false
	add_child(_sparks)


func _process(_delta: float) -> void:
	var t: Control = _target.get_ref() as Control if _target != null else null
	if t != null and t.is_inside_tree() and t.modulate.a > 0.01:
		var head := t.get_global_transform() * (t.size / 2.0)
		add_point(head)
		_sparks.global_position = head
		_sparks.emitting = true
		while get_point_count() > MAX_POINTS:
			remove_point(0)
		return
	_sparks.emitting = false
	if get_point_count() > 0:
		remove_point(0)
	else:
		queue_free()

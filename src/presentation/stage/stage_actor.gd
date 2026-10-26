class_name StageActor extends Node3D
## ⑤ Presentation：戦闘の 3D アクター 1 体（KayKit のモデル ＋ 武器 ＋ AnimationPlayer）。BattleStage が作って持つ。
## 位置 = home（UnitView の立ち絵の足元。BattleStage が毎フレーム決める）＋ offset（踏み込みの Tween）。
## 動作は strike（攻撃 1 回）/ perform（攻撃以外）/ react（被弾）/ die で始め、終わると待機に戻る。死亡後は倒れた姿勢のまま。
## 戻り値の秒は「再生の時間」（Presenter の速度を掛ける前）。AnimationPlayer と Tween には speed を掛けて合わせる。

## 倒れきって消え始めた（BattleStage が死亡のエフェクトを出す）。
signal vanishing(actor: StageActor)

## 向き：真横（90 度）から少しカメラ側へ振って顔が見えるようにする。
const FACING_YAW_DEG: float = 65.0
const BLEND: float = 0.1
## 攻撃・動作のクリップの再生倍率（素材のままだと戦闘のテンポには少し遅い）。
const ACTION_RATE: float = 1.3
const APPROACH: float = 0.16
const RETREAT: float = 0.22
## 攻撃のクリップが終わってから戻り始めるまで（連続攻撃はこの間に次の strike が来る）。
const LINGER: float = 0.1
## 踏み込んだときの相手との距離（両者の身長の和に掛ける）。
const GAP_PER_HEIGHT: float = 0.5
const FLASH_SECONDS: float = 0.18
## 照準の輪郭線（inverted hull。仕組みはシェーダーの冒頭）。太さはワールド単位（1 = PIXELS_PER_UNIT ピクセル）。
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/target_outline.gdshader")
const OUTLINE_COLOR: Color = Color(1, 1, 1)
const OUTLINE_WIDTH: float = 0.05
## 倒れるクリップの再生速度と、待つ上限（これを過ぎたらクリップの途中でも消え始める）。
## 死亡演出は全体を 1.7 倍速にしてある（2026-10-21、ユーザー指定。元は等速・0.9 / 0.35 / 0.5 秒）。
const DEATH_RATE: float = 1.7
const DEATH_HOLD_MAX: float = 0.53
## 倒れるクリップが終わってから消えるまで。
const CORPSE_LINGER: float = 0.2
const CORPSE_FADE: float = 0.3

var uid: int = -1
## +1 = 右向き（プレイヤー）、-1 = 左向き（敵）。
var facing: float = 1.0
var home: Vector3 = Vector3.ZERO
var offset: Vector3 = Vector3.ZERO
## ワールド単位の身長（拡大率込み）。
var height: float = 2.0
var dead: bool = false
var speed: float = 1.0:
	set(value):
		speed = value
		if _anim != null:
			_anim.speed_scale = value
		if _move_tween != null and _move_tween.is_valid():
			_move_tween.set_speed_scale(value)

var _spec: Dictionary = {}
var _move: StringName = &""
var _model: Node3D
var _anim: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _attack_index: int = 0
var _engaged: bool = false
var _return_in: float = -1.0
var _move_tween: Tween
var _flash_material: StandardMaterial3D
var _flash_left: float = 0.0
var _outline_material: ShaderMaterial
var _targeted: bool = false


## spec は ActorCatalog の表（_resolve 済み）。
func setup(p_uid: int, spec: Dictionary, p_facing: float) -> void:
	uid = p_uid
	_spec = spec
	facing = p_facing
	name = "Actor_%d" % uid
	_model = (load(ActorCatalog.MODELS % spec["model"]) as PackedScene).instantiate() as Node3D
	var s: float = spec.get("scale", 1.0)
	_model.scale = Vector3.ONE * s
	_model.rotation.y = deg_to_rad(FACING_YAW_DEG) * facing
	add_child(_model)
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		_attach(skeleton, &"handslot.r", spec.get("right", ""))
		_attach(skeleton, &"handslot.l", spec.get("left", ""))
	_collect_meshes(_model)
	height = _measure_height() * s
	_anim = AnimationPlayer.new()
	_anim.name = "AnimationPlayer"
	_model.add_child(_anim)
	_anim.root_node = NodePath("..")
	for lib_name: String in ActorCatalog.RIG_LIBRARIES[spec["rig"]]:
		_anim.add_animation_library(StringName(lib_name), load(ActorCatalog.ANIMS % lib_name) as AnimationLibrary)
	var idle := _anim.get_animation(_clip(ActorCatalog.ACT_IDLE))
	if idle != null:
		idle.loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.speed_scale = speed
	_play(ActorCatalog.ACT_IDLE)
	# 待機の動きが全員そろわないように、開始位置をずらす。
	if idle != null and idle.length > 0.0:
		_anim.seek(fmod(uid * 0.37, idle.length), true)


func _process(delta: float) -> void:
	position = home + offset
	if _return_in >= 0.0:
		_return_in -= delta * speed
		if _return_in < 0.0:
			_retreat()
	if _flash_left > 0.0:
		_flash_left -= delta * speed
		_flash_material.albedo_color.a = 0.75 * clampf(_flash_left / FLASH_SECONDS, 0.0, 1.0)
		if _flash_left <= 0.0:
			_refresh_overlay()


## この行動で使うクリップの上書き（ActorCatalog の moves）。&"" で解除。
func set_move(move_id: StringName) -> void:
	_move = move_id
	_attack_index = 0


## target_x（ワールド座標）の相手を 1 回攻撃する。当たる瞬間までの秒を返す。
func strike(target: StageActor) -> float:
	if dead:
		return 0.0
	var attacks: Array = _clip_list(ActorCatalog.ACT_ATTACK)
	if attacks.is_empty():
		return 0.0
	var clip := StringName(attacks[_attack_index % attacks.size()])
	_attack_index += 1
	_return_in = -1.0
	var approach := 0.0
	if not _spec.get("ranged", false) and not _spec.get("in_place", false) and target != null and target != self:
		var gap := GAP_PER_HEIGHT * (height + target.height)
		var want := Vector3(target.home.x - facing * gap - home.x, 0.0, 0.0)
		if not _engaged or not offset.is_equal_approx(want):
			approach = APPROACH
			_tween_offset(want, APPROACH, Tween.TRANS_QUAD, Tween.EASE_OUT)
		_engaged = true
	return approach + _play_action(clip)


## 攻撃以外の動作（ACT_BLOCK / ACT_BUFF / ACT_DEBUFF / ACT_CAST / ACT_SPAWN）。効果が出る瞬間までの秒を返す。
func perform(act: StringName) -> float:
	if dead:
		return 0.0
	var clip := _clip(act)
	if clip == &"" or not _anim.has_animation(clip):
		return 0.0
	_return_in = -1.0
	return _play_action(clip)


## 照準の輪郭線の表示（UnitView.targeted_changed から）。
func set_targeted(on: bool) -> void:
	_targeted = on and not dead
	_refresh_overlay()


func is_targeted() -> bool:
	return _targeted


## 被弾。guarded = ブロックで受けきった。
func react(guarded: bool) -> void:
	if dead:
		return
	if not guarded:
		_flash()
	var clip := _clip(ActorCatalog.ACT_GUARD_HIT if guarded else ActorCatalog.ACT_HIT)
	if _engaged and not guarded:
		return   # 踏み込んで攻撃中に反撃（トゲなど）を受けたときは、攻撃の動きを止めない
	if clip != &"" and _anim.has_animation(clip):
		_anim.play(clip, 0.05, ACTION_RATE)


func die() -> void:
	if dead:
		return
	dead = true
	set_targeted(false)
	_return_in = -1.0
	_engaged = false
	_tween_offset(Vector3.ZERO, RETREAT, Tween.TRANS_QUAD, Tween.EASE_OUT)
	var clip := _clip(ActorCatalog.ACT_DEATH)
	if clip != &"" and _anim.has_animation(clip):
		_anim.play(clip, BLEND, DEATH_RATE)
		# 倒れるクリップの終わりまで待つと長い（骸骨は 2 秒）ので、DEATH_HOLD_MAX で打ち切って消し始める。
		var t := create_tween()
		t.set_speed_scale(speed)
		t.tween_interval(minf(_anim.get_animation(clip).length / DEATH_RATE, DEATH_HOLD_MAX))
		t.tween_callback(_fade_out)
	else:
		_fade_out()


## 再生を経ずに倒れた状態にする（同期・再開時）。倒れた敵は残さないので隠す。
func set_dead_pose() -> void:
	if dead:
		return
	dead = true
	set_targeted(false)
	offset = Vector3.ZERO
	var clip := _clip(ActorCatalog.ACT_DEATH_POSE)
	if clip != &"" and _anim.has_animation(clip):
		_anim.play(clip)
	visible = false


func current_clip() -> StringName:
	return _anim.current_animation if _anim != null else &""


func is_engaged() -> bool:
	return _engaged


## クリップを頭から再生する（前の動作の途中でも切り替える）。当たる瞬間までの秒を返す。
func _play_action(clip: StringName) -> float:
	var rate: float = _spec.get("rate", ACTION_RATE)
	_anim.play(clip, BLEND, rate)
	_anim.seek(0.0, true)
	var anim := _anim.get_animation(clip)
	return ActorCatalog.impact_of(clip, anim.length if anim != null else 0.0) / rate


func _play(act: StringName) -> void:
	var clip := _clip(act)
	if clip != &"" and _anim.has_animation(clip):
		_anim.play(clip, BLEND)


func _on_animation_finished(clip: StringName) -> void:
	if dead:
		return
	if _engaged:
		_return_in = LINGER
	if clip != _clip(ActorCatalog.ACT_IDLE):
		_play(ActorCatalog.ACT_IDLE)


func _retreat() -> void:
	_engaged = false
	_move = &""
	_tween_offset(Vector3.ZERO, RETREAT, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)


func _tween_offset(to: Vector3, seconds: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_speed_scale(speed)
	_move_tween.tween_property(self, "offset", to, seconds).set_trans(trans).set_ease(easing)


func _clip(act: StringName) -> StringName:
	var v: Variant = _lookup(act)
	if v is Array:
		return StringName((v as Array)[0]) if not (v as Array).is_empty() else &""
	return StringName(v) if v != null else &""


func _clip_list(act: StringName) -> Array:
	var v: Variant = _lookup(act)
	if v is Array:
		return v
	return [v] if v != null else []


func _lookup(act: StringName) -> Variant:
	var moves: Dictionary = _spec.get("moves", {})
	if moves.has(_move) and (moves[_move] as Dictionary).has(act):
		return moves[_move][act]
	return (_spec["clips"] as Dictionary).get(act)


func _attach(skeleton: Skeleton3D, bone: StringName, weapon: String) -> void:
	if weapon.is_empty() or skeleton.find_bone(bone) < 0:
		return
	var slot := BoneAttachment3D.new()
	slot.bone_name = bone
	skeleton.add_child(slot)
	slot.add_child((load(ActorCatalog.WEAPONS % weapon) as PackedScene).instantiate())


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for c in node.get_children():
		_collect_meshes(c)


## 体（武器を除く）の高さ。BoneAttachment の下は武器なので数えない。
func _measure_height() -> float:
	var top := 0.0
	for m in _meshes:
		if m.get_parent() is BoneAttachment3D or m.get_parent().get_parent() is BoneAttachment3D:
			continue
		var box := m.get_aabb()
		top = maxf(top, box.position.y + box.size.y)
	return top if top > 0.0 else 2.0


func _flash() -> void:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.albedo_color = Color(1, 1, 1, 0)
	_flash_left = FLASH_SECONDS
	_flash_material.albedo_color.a = 0.75
	_refresh_overlay()


## 重ねる材質は 1 枠なので、被弾の白い光と輪郭線は next_pass でつなぐ。
func _refresh_overlay() -> void:
	var outline: Material = null
	if _targeted:
		if _outline_material == null:
			_outline_material = ShaderMaterial.new()
			_outline_material.shader = OUTLINE_SHADER
			_outline_material.set_shader_parameter(&"outline_color", OUTLINE_COLOR)
			_outline_material.set_shader_parameter(&"width", OUTLINE_WIDTH)
		outline = _outline_material
	var material: Material = outline
	if _flash_left > 0.0:
		_flash_material.next_pass = outline
		material = _flash_material
	for m in _meshes:
		m.material_overlay = material


## 倒れきったら少し置いてから薄くして消す。
func _fade_out() -> void:
	var t := create_tween()
	t.set_speed_scale(speed)
	t.tween_callback(func() -> void: vanishing.emit(self)).set_delay(CORPSE_LINGER)
	for m in _meshes:
		t.parallel().tween_property(m, "transparency", 1.0, CORPSE_FADE).set_delay(CORPSE_LINGER)
	t.tween_callback(hide)

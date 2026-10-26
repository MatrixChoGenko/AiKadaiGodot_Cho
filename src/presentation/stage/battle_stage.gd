class_name BattleStage extends SubViewportContainer
## ⑤ Presentation：戦闘の 3D の舞台（Architecture §14.6）。Field の一番下（UnitView の HUD より下）に透明な SubViewport を 1 枚重ね、
## 全員の StageActor を 1 つの World3D に置く。カメラは真横の正投影（基準解像度で 1 ワールド単位 = PIXELS_PER_UNIT ピクセル）。
## 2D のレイアウトが正：アクターの足元は UnitView の立ち絵の矩形の下辺中央に毎フレーム合わせる。照準・カードの飛ぶ先・
## フローティング数字は今までどおり 2D の矩形（UnitView.portrait_rect / hit_point）で決まる。
## Field ごと揺れるので画面の揺れ（Architecture §14.5）にもそのまま付いてくる。入力は受けない（mouse_filter = IGNORE）。

const PIXELS_PER_UNIT: float = 90.0
const CAMERA_DISTANCE: float = 40.0
## 立ち絵の矩形の下辺から足元までの余白（ピクセル）。
const FOOT_MARGIN: float = 4.0
## 立ち絵の矩形の大きさ（身長から決める）。幅はこの範囲に収める。
const PORTRAIT_MIN_WIDTH: float = 200.0
const PORTRAIT_MAX_WIDTH: float = 300.0
## 舞台のエフェクト（StageEffect のシーン）。StageDirector が戦闘のイベントから出す。
const EFFECTS: Dictionary[StringName, PackedScene] = {
	&"hit": preload("res://scenes/fx/stage/hit_spark.tscn"),
	&"guard": preload("res://scenes/fx/stage/guard_spark.tscn"),
	&"block": preload("res://scenes/fx/stage/block_gain.tscn"),
	&"death": preload("res://scenes/fx/stage/death_poof.tscn"),
	&"shatter": preload("res://scenes/fx/stage/block_shatter.tscn"),
	&"heal": preload("res://scenes/fx/stage/heal.tscn"),
	&"poison": preload("res://scenes/fx/stage/poison_apply.tscn"),
	&"poison_tick": preload("res://scenes/fx/stage/poison_tick.tscn"),
	&"strength": preload("res://scenes/fx/stage/strength_up.tscn"),
	&"weak": preload("res://scenes/fx/stage/weak_apply.tscn"),
	&"vulnerable": preload("res://scenes/fx/stage/vulnerable_apply.tscn"),
	&"spawn": preload("res://scenes/fx/stage/spawn_dirt.tscn"),
}
## エフェクトを出す奥行き（キャラクターより手前。材質も no_depth_test で常に手前に描く）。
const FX_DEPTH: float = 1.5
## 先読み（warm_up）で出すときの大きさ。見えないほど小さくして、シェーダーのコンパイルだけを済ませる。
const WARM_UP_SIZE: float = 0.001
## 死亡のエフェクトを後ろ（向きの反対）へずらす量（身長の割合）。
const DEATH_FX_BACK: float = 0.3

var _viewport: SubViewport
var _camera: Camera3D
var _actors: Dictionary[int, StageActor] = {}
var _anchors: Dictionary[int, UnitView] = {}
var _speed: float = 1.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 透明な SubViewport に半透明の物（エフェクト・消えていく死体）を描くと、色にアルファが掛かった値（乗算済み）が残る。
	# そのまま普通に重ねると半透明の所が暗く濁るので、乗算済みアルファとして合成する。
	var premultiplied := CanvasItemMaterial.new()
	premultiplied.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = premultiplied
	_viewport = SubViewport.new()
	_viewport.name = "Viewport"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	_camera.near = 1.0
	_camera.far = CAMERA_DISTANCE * 2.0
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	sun.light_energy = 1.1
	_viewport.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.7)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	_warm_up.call_deferred()


## uid のユニットに 3D アクターを付ける。spec が空（表に無い敵）なら何もしないで null。
## 付けたら UnitView は立ち絵の図形を描かなくなり、矩形の大きさをアクターの身長に合わせる。
func add_actor(uid: int, view: UnitView, spec: Dictionary, facing: float) -> StageActor:
	if spec.is_empty():
		return null
	var actor := StageActor.new()
	_viewport.add_child(actor)
	actor.setup(uid, spec, facing)
	actor.speed = _speed
	_actors[uid] = actor
	_anchors[uid] = view
	view.targeted_changed.connect(func(_v: UnitView, on: bool) -> void: actor.set_targeted(on))
	actor.vanishing.connect(_on_actor_vanishing)
	var tall := actor.height * PIXELS_PER_UNIT
	view.set_stage_mode(Vector2(clampf(tall * 0.8, PORTRAIT_MIN_WIDTH, PORTRAIT_MAX_WIDTH), tall + FOOT_MARGIN))
	return actor


func actor(uid: int) -> StageActor:
	return _actors.get(uid)


func actor_count() -> int:
	return _actors.size()


## 再生の速さ（Presenter の倍率）。アニメーションと移動の Tween に掛ける。
func set_speed(value: float) -> void:
	if is_equal_approx(value, _speed):
		return
	_speed = value
	for a: StageActor in _actors.values():
		a.speed = value
	for c in _viewport.get_children():
		if c is StageEffect:
			(c as StageEffect).speed = value


## kind のエフェクトを at（ワールド座標）に 1 回出す。facing = -1 で左右反転、size は拡大率。終わると自分で消える。
func spawn_fx(kind: StringName, at: Vector3, facing: float = 1.0, size: float = 1.0) -> StageEffect:
	var scene: PackedScene = EFFECTS.get(kind)
	if scene == null:
		Log.warn(&"stage", "unknown stage fx: %s" % kind)
		return null
	var fx := scene.instantiate() as StageEffect
	fx.speed = _speed
	_viewport.add_child(fx)
	fx.play(at, facing, size)
	return fx


## アクター a の体の高さ ratio の所に出し、アクターが動いても付いていく（状態異常・回復・ブロックなど）。大きさは身長に合わせる。
func spawn_on(kind: StringName, a: StageActor, ratio: float) -> StageEffect:
	var fx := spawn_fx(kind, body_point(a, ratio), 1.0, a.height / 2.0)
	if fx != null:
		fx.anchor = a
		fx.anchor_offset = Vector3(0.0, a.height * ratio, FX_DEPTH)
	return fx


## アクターの体の高さ ratio（0 = 足元、1 = 頭）の点を、エフェクトの奥行きで返す。
static func body_point(a: StageActor, ratio: float) -> Vector3:
	return Vector3(a.position.x, a.position.y + a.height * ratio, FX_DEPTH)


## 立ち絵の矩形からアクターの足元（画面の座標）。
static func foot_of(rect: Rect2) -> Vector2:
	return Vector2(rect.get_center().x, rect.end.y - FOOT_MARGIN)


## 画面（キャンバス）の座標 → 舞台の奥行き 0 の平面上の点。
func to_world(global_pos: Vector2) -> Vector3:
	var local := get_global_transform().affine_inverse() * global_pos
	if size.x > 0.0 and size.y > 0.0:
		local *= Vector2(_viewport.size) / size
	return _camera.project_position(local, CAMERA_DISTANCE)


## 初めて出すエフェクトでカクつかないように、全種類を見えない大きさで 1 回ずつ出してシェーダーをコンパイルさせておく
## （Compatibility レンダラーはシェーダーを初めて描くときにコンパイルする）。
func _warm_up() -> void:
	for kind: StringName in EFFECTS:
		spawn_fx(kind, Vector3(0, 0, FX_DEPTH), 1.0, WARM_UP_SIZE)


## 倒れたアクターが消え始めた所に、煙と骨のエフェクトを出す。倒れるクリップは後ろへ倒れるので、少し後ろへずらす。
func _on_actor_vanishing(a: StageActor) -> void:
	var at := body_point(a, 0.3)
	at.x -= a.facing * a.height * DEATH_FX_BACK
	spawn_fx(&"death", at, 1.0, a.height / 2.0)


func _process(_delta: float) -> void:
	if _viewport == null or _viewport.size.y <= 0 or size.y < 1.0:
		return
	# 2D の座標（キャンバスの単位）で 1 単位 = PIXELS_PER_UNIT。ウィンドウの大きさが変わっても HUD と同じ比率で縮む。
	_camera.size = size.y / PIXELS_PER_UNIT
	for uid: int in _actors:
		var view := _anchors[uid]
		if not is_instance_valid(view):
			continue
		_actors[uid].home = to_world(foot_of(view.portrait_rect()))

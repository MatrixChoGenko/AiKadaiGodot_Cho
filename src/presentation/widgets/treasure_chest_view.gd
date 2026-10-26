class_name TreasureChestView extends Control
## ⑤ Presentation：宝箱の部屋（StS2 の宝箱のマス）。全画面の背景の絵（treasure_vault）に描かれた宝箱を、クリックして開ける。
## - 待っている間：上から差す光の筋と金色の塵がゆっくり動く（god_rays.gdshader）。
## - ホバー：宝箱の形（絵の px の多角形 CHEST_POLY）に沿って白い輪郭と薄い明るさを重ね、指のカーソルにする。
## - クリック（open()）：画面が白金に光って揺れ、その光の中で絵が「開いた宝箱」（treasure_vault_open。同じ構図）に切り替わる。
##   続けて中から光があふれ、回る光の筋と衝撃の輪が広がり、金貨が爆発的に飛び散ったあと噴水のように吹き上がり続け、
##   宝石と虹色のきらめきが舞う。OPEN_TIME 秒後に opened を出す（報酬画面が戦利品のパネルを出す）。
## 絵の座標は、背景と同じ「覆うように拡大」の写し方で画面へ写す（_layout）。2 枚の絵は宝箱の外がほぼ同じなので、重ねて切り替えられる。

signal opened

const BACKDROP: Texture2D = preload("res://assets/textures/backgrounds/treasure_vault.jpg")
const BACKDROP_OPEN: Texture2D = preload("res://assets/textures/backgrounds/treasure_vault_open.jpg")
const RAYS_SHADER: Shader = preload("res://assets/shaders/god_rays.gdshader")
const BURST_SHADER: Shader = preload("res://assets/shaders/card_rays.gdshader")
const HALO: Texture2D = preload("res://assets/textures/ui/reward/halo.png")
const RING: Texture2D = preload("res://assets/textures/fx/fx_ring.png")
const COIN: Texture2D = preload("res://assets/textures/ui/hud/coin.png")
const GEM: Texture2D = preload("res://assets/textures/fx/fx_shard.png")
const SPARKLE: Texture2D = preload("res://assets/textures/fx/fx_sparkle.png")
## 絵（2752x1536）の中の宝箱の輪郭（時計回り）と、中身（開いた絵で光っている所）の中心。
const CHEST_POLY: PackedVector2Array = [
	Vector2(960, 890), Vector2(974, 748), Vector2(1012, 676), Vector2(1084, 640), Vector2(1200, 634), Vector2(1400, 642),
	Vector2(1600, 655), Vector2(1700, 661), Vector2(1770, 692), Vector2(1804, 760), Vector2(1810, 860), Vector2(1801, 1000),
	Vector2(1796, 1195), Vector2(1744, 1236), Vector2(1625, 1290), Vector2(1420, 1280), Vector2(1150, 1260), Vector2(1012, 1250),
	Vector2(992, 1205), Vector2(996, 950), Vector2(957, 905),
]
const MOUTH: Vector2 = Vector2(1370, 830)
const OUTLINE_WIDTH: float = 9.0   # 絵の px
const GOLD: Color = Color(1.0, 0.8, 0.4)
## 開けてから opened を出すまでの秒数（金貨の噴水を見せる間）。
const OPEN_TIME: float = 1.05
## 開けた瞬間の画面の揺れ（px）と秒数、金貨の噴水が吹き上がり続ける秒数。
const SHAKE: float = 12.0
const SHAKE_TIME: float = 0.35
const FOUNTAIN_TIME: float = 0.9

var is_open: bool = false
var hovered: bool = false

var _k: float = 1.0
var _off: Vector2 = Vector2.ZERO
var _shake: Vector2 = Vector2.ZERO
var _view: Control   # 揺らす入れ物（背景・光・粒）
var _open_bg: TextureRect
var _chest: Node2D
var _outline: Line2D
var _fill: Polygon2D
var _glow: TextureRect
var _ring: TextureRect
var _burst: ColorRect
var _flash: ColorRect
var _coins: GPUParticles2D
var _fountain: GPUParticles2D
var _gems: GPUParticles2D
var _glitter: GPUParticles2D


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.add_child(_cover(BACKDROP))
	_open_bg = _cover(BACKDROP_OPEN)
	_open_bg.visible = false
	_view.add_child(_open_bg)
	var rays := ColorRect.new()
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rm := ShaderMaterial.new()
	rm.shader = RAYS_SHADER
	rm.set_shader_parameter(&"origin", Vector2(0.5, -0.12))
	rm.set_shader_parameter(&"angle_deg", 90.0)
	rm.set_shader_parameter(&"spread_deg", 16.0)
	rm.set_shader_parameter(&"ray_color", Color(1.0, 0.82, 0.48))
	rm.set_shader_parameter(&"intensity", 0.16)
	rm.set_shader_parameter(&"ray_length", 1.1)
	rm.set_shader_parameter(&"dust_amount", 0.55)
	rays.material = rm
	_view.add_child(rays)
	# 宝箱の輪郭（絵の座標で描き、_chest の変換で画面へ）
	_chest = Node2D.new()
	_view.add_child(_chest)
	_fill = Polygon2D.new()
	_fill.polygon = CHEST_POLY
	_fill.color = Color(1, 1, 1, 0.07)
	_fill.material = _additive()
	_chest.add_child(_fill)
	_outline = Line2D.new()
	_outline.points = CHEST_POLY
	_outline.closed = true
	_outline.width = OUTLINE_WIDTH
	_outline.default_color = Color(1, 1, 1, 0.95)
	_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_outline.antialiased = true
	_chest.add_child(_outline)
	_set_hover(false)
	# 開く演出
	_burst = ColorRect.new()
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = BURST_SHADER
	bm.set_shader_parameter(&"speed", 0.9)
	bm.set_shader_parameter(&"intensity", 1.1)
	_burst.material = bm
	_burst.visible = false
	_view.add_child(_burst)
	_glow = _additive_rect(HALO)
	_ring = _additive_rect(RING)
	_coins = _make_particles(COIN, 80, 1.7, 0.3, Color.WHITE, 0.0)
	_set_motion(_coins, Vector3(170, 10, 0), 72.0, 650.0, 1400.0, 1700.0)
	_coins.one_shot = true
	_coins.explosiveness = 0.92
	_fountain = _make_particles(COIN, 56, 1.5, 0.26, Color.WHITE, 0.0)
	_set_motion(_fountain, Vector3(110, 8, 0), 26.0, 700.0, 1150.0, 1700.0)
	_gems = _make_particles(GEM, 32, 1.6, 0.24, Color(1.0, 0.3, 0.45), 0.5)
	_set_motion(_gems, Vector3(150, 10, 0), 60.0, 500.0, 1100.0, 1500.0)
	_gems.one_shot = true
	_gems.explosiveness = 0.85
	_glitter = _make_particles(SPARKLE, 70, 1.8, 0.16, Color(1.0, 0.9, 0.6), 0.5, true)
	_set_motion(_glitter, Vector3(260, 60, 0), 180.0, 60.0, 280.0, -40.0)
	_glitter.one_shot = true
	_glitter.explosiveness = 0.6
	for p: GPUParticles2D in [_coins, _fountain, _gems, _glitter]:
		_view.add_child(p)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 0.92, 0.7, 0.0)
	_flash.material = _additive()
	add_child(_flash)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


## 宝箱を開ける（クリックと同じ経路）。animate = false なら演出なしで開いた絵にする（すぐに opened を出す）。
func open(animate: bool = true) -> void:
	if is_open:
		return
	is_open = true
	_set_hover(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not animate:
		_open_bg.visible = true
		opened.emit()
		return
	_layout()
	var t := create_tween().set_parallel(true)
	# 白金の閃光と揺れ。閃光の一番明るい所で開いた絵に切り替える
	t.tween_property(_flash, "color:a", 0.55, 0.07)
	t.tween_property(_flash, "color:a", 0.0, 0.55).set_delay(0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_bg.modulate.a = 0.0
	_open_bg.visible = true
	t.tween_property(_open_bg, "modulate:a", 1.0, 0.1).set_delay(0.04)
	t.tween_method(_set_shake, 1.0, 0.0, SHAKE_TIME)
	# 中からあふれる光・回る光の筋・衝撃の輪
	t.tween_property(_glow, "modulate:a", 1.0, 0.1)
	t.tween_property(_glow, "scale", Vector2(1.9, 1.5), 0.45).from(Vector2(0.4, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_glow, "modulate:a", 0.45, 0.6).set_delay(0.3)
	_burst.visible = true
	_burst.modulate.a = 0.0
	t.tween_property(_burst, "modulate:a", 1.0, 0.12)
	t.tween_property(_burst, "scale", Vector2.ONE, 0.55).from(Vector2.ONE * 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_burst, "modulate:a", 0.35, 0.7).set_delay(0.45)
	t.tween_property(_ring, "modulate:a", 1.0, 0.05)
	t.tween_property(_ring, "scale", Vector2.ONE * 4.0, 0.5).from(Vector2.ONE * 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(_ring, "modulate:a", 0.0, 0.4).set_delay(0.1)
	# 金貨の爆発 → 噴水、宝石、虹色のきらめき
	t.tween_callback(_coins.restart).set_delay(0.04)
	t.tween_callback(_gems.restart).set_delay(0.06)
	t.tween_callback(_glitter.restart).set_delay(0.08)
	t.tween_callback(func() -> void: _fountain.emitting = true).set_delay(0.12)
	t.tween_callback(func() -> void: _fountain.emitting = false).set_delay(0.12 + FOUNTAIN_TIME)
	t.tween_callback(opened.emit).set_delay(OPEN_TIME)


## 画面の点 p が宝箱の上か。
func is_over_chest(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon((p - _off) / _k, CHEST_POLY)


## 開いた絵を出しているか（テスト用）。
func shows_open_image() -> bool:
	return _open_bg.visible


func _gui_input(event: InputEvent) -> void:
	if is_open:
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		_set_hover(is_over_chest(mm.position))
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and is_over_chest(mb.position):
		accept_event()
		open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hover(false)


func _set_hover(on: bool) -> void:
	hovered = on
	_outline.visible = on
	_fill.visible = on
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW


## 揺れ：強さ s（1 → 0）でランダムな向きにずらす（入れ物ごと。閃光は揺らさない）。
func _set_shake(s: float) -> void:
	_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE * s * _k / 0.703
	_view.position = _shake


func _layout() -> void:
	_view.size = size
	var img := BACKDROP.get_size()
	_k = maxf(size.x / img.x, size.y / img.y)
	_off = (size - img * _k) / 2.0
	_chest.position = _off
	_chest.scale = Vector2.ONE * _k
	var mouth := _off + MOUTH * _k
	_glow.size = Vector2(1000, 600) * _k
	_ring.size = Vector2(520, 520) * _k
	_burst.size = Vector2.ONE * 2400.0 * _k
	for c: Control in [_glow, _ring, _burst]:
		c.pivot_offset = c.size / 2.0
		c.position = mouth - c.size / 2.0
	for p: GPUParticles2D in [_coins, _fountain, _gems, _glitter]:
		p.position = mouth
		p.scale = Vector2.ONE * _k / 0.703   # 1080 の高さで合わせた粒の大きさ・飛ぶ距離


static func _cover(tex: Texture2D) -> TextureRect:
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bg


func _additive_rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = Color(GOLD, 0.0)
	r.material = _additive()
	_view.add_child(r)
	return r


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## 粒（金貨・宝石・きらめき）。動きは _set_motion。hue = 色相のばらつき（虹色）。additive = 加算で光らせる。
static func _make_particles(tex: Texture2D, amount: int, lifetime: float, size_scale: float, color: Color, hue: float,
		additive: bool = false) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.texture = tex
	if additive:
		p.material = _additive()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.direction = Vector3(0, -1, 0)
	m.angular_velocity_min = -540.0
	m.angular_velocity_max = 540.0
	m.scale_min = size_scale * 0.6
	m.scale_max = size_scale * 1.3
	m.color = color
	m.hue_variation_min = -hue
	m.hue_variation_max = hue
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.08, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var tex_ramp := GradientTexture1D.new()
	tex_ramp.gradient = ramp
	m.color_ramp = tex_ramp
	p.process_material = m
	return p


## 出る範囲（箱の半分の大きさ）・上向きからの広がり（度）・初速・重力（下向きが正。負なら浮かぶ）。
static func _set_motion(p: GPUParticles2D, box: Vector3, spread: float, v_min: float, v_max: float, gravity: float) -> void:
	var m := p.process_material as ParticleProcessMaterial
	m.emission_box_extents = box
	m.spread = spread
	m.initial_velocity_min = v_min
	m.initial_velocity_max = v_max
	m.gravity = Vector3(0, gravity, 0)

class_name CardView extends Control
## ⑤ Presentation：カード面（GameDesign §6.5 / Architecture §14.5）。表示だけを担い、ルールは知らない。
## フレームは画像（金属の色 = レアリティ、UiGlyphs.RARITY_FRAMES）。各欄はフレームの画像に対する割合で置いてある
## （tools/card_frames.py の加工と一致。大きさを変えても崩れない）。
## 要素：左上の丸 = コスト、絵の窓 = イラスト（素材なしのときは種類の文字）と種類名、名前の札、羊皮紙 = 説明（CardText の BBCode）、
## 下の丸 2 つ = 種類の記号。
## 手札では target_* に向けて自分で補間する（HandView が目標の姿勢を決める）。

signal pressed(view: CardView)
signal hover_changed(view: CardView, hovered: bool)

const BASE_SIZE: Vector2 = Vector2(300, 420)
const FOLLOW_SPEED: float = 16.0
const COST_DOWN_COLOR: Color = Color(0.5, 1.0, 0.55)
const COST_UP_COLOR: Color = Color(1.0, 0.5, 0.45)
const NAME_COLOR: Color = Color(0.24, 0.14, 0.07)
const NAME_UPGRADED_COLOR: Color = Color(0.1, 0.42, 0.14)
const NAME_MAX_FONT: int = 19
const NAME_MIN_FONT: int = 12
## 説明は DESC_FONT から入りきるまで字を小さくし、短い説明は行数が増えない範囲で DESC_MAX_FONT まで大きくする
## （「る。」だけが次の行に落ちるのを避ける）。羊皮紙が明るいので、CardText の増減の色も濃い色に置き換える。
const DESC_FONT: int = 18
const DESC_MAX_FONT: int = 21
const DESC_MIN_FONT: int = 11
const DESC_COLORS: Dictionary[String, String] = {CardText.COLOR_UP: "#17692a", CardText.COLOR_DOWN: "#a8231b"}
## 山札から引いたときに裏面を見せる秒。
const BACK_FADE: float = 0.22
## 輪郭グロー（assets/shaders/card_glow.gdshader）：使用可能 = 淡い青白、選択中（手札で持ち上げ中・一覧で選択中）= 明るい金色。
const GLOW_PLAYABLE: Color = Color(0.55, 0.85, 1.0)
const GLOW_SELECTED: Color = Color(1.0, 0.8, 0.3)
const GLOW_SELECTED_INTENSITY: float = 1.8
## スイープ光（assets/shaders/card_shine.gdshader）：SHINE_DELAY 秒乗せ続けたら SHINE_TIME 秒で 1 回流す。
## 待っている間に離れたら取り消す。流れ始めたら最後まで流す。
const SHINE_DELAY: float = 0.3
const SHINE_TIME: float = 0.5

## 戦闘中・デッキのカード。CardData だけを表示するとき（報酬・ショップ）は null。
var card: Card
var data: CardData

## 手札での目標の姿勢（中心の位置）。follow = true のときだけ補間する。
var follow: bool = false
var target_center: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0
var target_scale: float = 1.0

## ホバー中にカードの横へ用語の説明を出すか（U11。手札でドラッグ中などは持ち主が hide_tips() する）。
var tips_enabled: bool = true

var _text: String = ""
var _cost: int = -1
var _tips: CardTips
var _playable: bool = false
var _selected: bool = false
var _shine_tween: Tween

@onready var _frame: TextureRect = %Frame
@onready var _glow: ColorRect = %Glow
@onready var _shine: TextureRect = %Shine
@onready var _cost_orb: TextureRect = %CostOrb
@onready var _sparkle: TextureRect = %Sparkle
@onready var _name: Label = %NameLabel
@onready var _art_texture: TextureRect = %ArtTexture
@onready var _art_label: Label = %ArtLabel
@onready var _type: Label = %TypeLabel
@onready var _desc: RichTextLabel = %Desc
@onready var _cost_badge: GlyphBadge = %Cost
@onready var _type_badges: Array[GlyphBadge] = [%TypeLeft, %TypeRight]
@onready var _back: TextureRect = %Back


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_glow()
	if data != null:
		_apply()


## 表示する内容を決める。text は CardText の結果（BBCode）。cost < 0 なら基本のコストを出す。
func show_card(p_data: CardData, text: String, p_card: Card = null, cost: int = -1) -> void:
	data = p_data
	card = p_card
	_text = text
	_cost = cost
	if is_node_ready():
		_apply()


## 説明とコストだけを更新する（戦闘中の動的テキスト）。
func update_text(text: String, cost: int = -1) -> void:
	if text == _text and cost == _cost:
		return
	_text = text
	_cost = cost
	if is_node_ready():
		_apply()


func set_playable(on: bool) -> void:
	_playable = on
	_update_glow()


func set_selected(on: bool) -> void:
	_selected = on
	_update_glow()


func is_glowing() -> bool:
	return _glow.visible


func _update_glow() -> void:
	if _glow == null:
		return
	_glow.visible = _playable or _selected
	var mat := _glow.material as ShaderMaterial
	mat.set_shader_parameter(&"glow_color", GLOW_SELECTED if _selected else GLOW_PLAYABLE)
	mat.set_shader_parameter(&"intensity", GLOW_SELECTED_INTENSITY if _selected else 1.0)


## スイープ光を 1 回流す（左上 → 右下）。delay 秒後に始める。始まる前なら cancel_pending_shine() で取り消せる。
func play_shine(delay: float = 0.0) -> void:
	if _shine_tween != null:
		_shine_tween.kill()
	_shine.visible = false
	var mat := _shine.material as ShaderMaterial
	_shine_tween = create_tween()
	if delay > 0.0:
		_shine_tween.tween_interval(delay)
	_shine_tween.tween_callback(func() -> void:
		mat.set_shader_parameter(&"progress", 0.0)
		_shine.visible = true)
	_shine_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"progress", v), 0.0, 1.0, SHINE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shine_tween.tween_callback(func() -> void:
		_shine.visible = false
		mat.set_shader_parameter(&"progress", -1.0))


## 待っている間（光がまだ出ていない）なら取り消す。流れている光は最後まで流す。
func cancel_pending_shine() -> void:
	if _shine_tween != null and _shine_tween.is_valid() and not _shine.visible:
		_shine_tween.kill()
		_shine_tween = null


func is_shining() -> bool:
	return _shine.visible


func set_dimmed(on: bool) -> void:
	var a := modulate.a
	modulate = Color(0.6, 0.6, 0.65, a) if on else Color(1, 1, 1, a)


## 中心の位置を直接置く（補間なし）。
func place_center(center: Vector2) -> void:
	position = center - size / 2.0
	target_center = center


func center() -> Vector2:
	return position + size / 2.0


func _process(delta: float) -> void:
	if not follow:
		return
	var t := 1.0 - exp(-FOLLOW_SPEED * delta)
	position = position.lerp(target_center - size / 2.0, t)
	rotation = lerp_angle(rotation, target_rotation, t)
	scale = scale.lerp(Vector2.ONE * target_scale, t)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


## 裏面から表へ返す演出（山札から引いたとき）。
func reveal_from_back() -> void:
	_back.visible = true
	_back.modulate.a = 1.0
	var t := _back.create_tween()
	t.tween_property(_back, "modulate:a", 0.0, BACK_FADE).set_delay(0.06)
	t.tween_callback(_back.hide)


func _apply() -> void:
	var rarity := UiText.frame_rarity(data)
	_frame.texture = UiGlyphs.RARITY_FRAMES.get(rarity, UiGlyphs.FRAME_BRONZE)
	_cost_orb.texture = UiGlyphs.RARITY_COST_ORBS.get(rarity, UiGlyphs.COST_ORB_BRONZE)
	# グロー・スイープ光・きらめきはフレームのアルファを型にする（金のフレームは王冠が上へはみ出す）
	_shine.texture = _frame.texture
	_sparkle.texture = _frame.texture
	(_glow.material as ShaderMaterial).set_shader_parameter(&"frame_tex", _frame.texture)
	_apply_sparkle(rarity)
	_name.text = data.name
	_name.add_theme_color_override(&"font_color", NAME_UPGRADED_COLOR if data.name.ends_with("+") else NAME_COLOR)
	_fit_name()
	_art_texture.texture = art_region(data.art, data.art_focus, _art_aspect())
	_art_texture.visible = data.art != null
	_art_label.visible = data.art == null
	var glyph: String = UiGlyphs.CARD_TYPE_GLYPHS.get(data.type, "")
	_art_label.text = glyph
	_type.text = UiText.card_type(data.type)
	for badge in _type_badges:
		badge.text = glyph
		badge.fill = UiGlyphs.CARD_TYPE_COLORS.get(data.type, Color.GRAY)
	var text := _text
	for from: String in DESC_COLORS:
		text = text.replace(from, DESC_COLORS[from])
	_desc.text = text
	_fit_desc()
	var label := UiText.cost_label(data, _cost)
	_cost_badge.visible = not label.is_empty()
	_cost_orb.visible = _cost_badge.visible
	_cost_badge.text = label
	_cost_badge.text_color = Color.WHITE
	if data.cost_mode == CardData.CostMode.FIXED and _cost >= 0 and _cost != data.cost:
		_cost_badge.text_color = COST_DOWN_COLOR if _cost < data.cost else COST_UP_COLOR


## 絵の窓の横 / 縦（ArtBox の anchor から。フレームの加工を変えても追従する）。
func _art_aspect() -> float:
	var box := _art_texture.get_parent() as Control
	return (box.anchor_right - box.anchor_left) * BASE_SIZE.x / ((box.anchor_bottom - box.anchor_top) * BASE_SIZE.y)


## 絵のうち窓に見せる部分（横幅いっぱい、上下は focus の位置）。窓より横長の絵は左右を中央で切る。
static func art_region(art: Texture2D, focus: float, aspect: float) -> Texture2D:
	if art == null:
		return null
	var full := art.get_size()
	var region := Rect2(Vector2.ZERO, full)
	if full.x / full.y < aspect:
		region.size.y = full.x / aspect
		region.position.y = (full.y - region.size.y) * clampf(focus, 0.0, 1.0)
	else:
		region.size.x = full.y * aspect
		region.position.x = (full.x - region.size.x) * 0.5
	var atlas := AtlasTexture.new()
	atlas.atlas = art
	atlas.region = region
	return atlas


## フレームのきらめき（UiGlyphs.RARITY_SPARKLES）。枠の数は範囲の中でカードごとに決める（同じカードはいつも同じ数）。
## 無いレアリティは非表示にして描画しない。
func _apply_sparkle(rarity: CardData.Rarity) -> void:
	var span: Vector2i = UiGlyphs.RARITY_SPARKLES.get(rarity, Vector2i.ZERO)
	var count := span.x + posmod(String(data.id).hash(), span.y - span.x + 1)
	_sparkle.visible = count > 0
	if count <= 0:
		return
	var mat := _sparkle.material as ShaderMaterial
	mat.set_shader_parameter(&"sparkle_count", count)
	mat.set_shader_parameter(&"sparkle_color", UiGlyphs.RARITY_SPARKLE_COLORS.get(rarity, Color.WHITE))
	mat.set_shader_parameter(&"has_crown", rarity == CardData.Rarity.RARE)
	mat.set_shader_parameter(&"seed", float(get_instance_id() % 997))


func sparkle_count() -> int:
	if not _sparkle.visible:
		return 0
	var count: int = (_sparkle.material as ShaderMaterial).get_shader_parameter(&"sparkle_count")
	return count


## 名前が札に入りきるまで字を小さくする。
func _fit_name() -> void:
	var font := _name.get_theme_font(&"font")
	var fs := NAME_MAX_FONT
	while fs > NAME_MIN_FONT and _name.size.x > 0.0 and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _name.size.x:
		fs -= 1
	_name.add_theme_font_size_override(&"font_size", fs)


## 説明の字の大きさを決める（DESC_FONT の説明を参照）。
func _fit_desc() -> void:
	var fs := DESC_FONT
	while fs > DESC_MIN_FONT and not _desc_fits(fs):
		fs -= 1
	if fs == DESC_FONT and _desc.size.y > 0.0:
		var lines := _desc.get_line_count()
		while fs < DESC_MAX_FONT and _desc_fits(fs + 1) and _desc.get_line_count() == lines:
			fs += 1
	_desc.add_theme_font_size_override(&"normal_font_size", fs)


func _desc_fits(fs: int) -> bool:
	_desc.add_theme_font_size_override(&"normal_font_size", fs)
	return _desc.size.y <= 0.0 or _desc.get_content_height() <= _desc.size.y


func desc_font_size() -> int:
	return _desc.get_theme_font_size(&"normal_font_size")


## 用語の説明を出す（用語が無ければ何もしない）。
func show_tips() -> void:
	if _tips != null or data == null:
		return
	var terms := UiText.card_terms(data)
	if terms.is_empty():
		return
	_tips = CardTips.new(self, terms)
	add_child(_tips)


func hide_tips() -> void:
	if _tips == null:
		return
	remove_child(_tips)
	_tips.queue_free()
	_tips = null


func tips_shown() -> bool:
	return _tips != null


func _on_mouse_entered() -> void:
	if tips_enabled:
		show_tips()
	play_shine(SHINE_DELAY)
	hover_changed.emit(self, true)


func _on_mouse_exited() -> void:
	hide_tips()
	cancel_pending_shine()
	hover_changed.emit(self, false)

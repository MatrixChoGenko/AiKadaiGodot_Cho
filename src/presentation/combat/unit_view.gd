class_name UnitView extends VBoxContainer
## ⑤ Presentation：戦闘ユニット 1 体の表示（GameDesign §15.4、U04）。立ち絵（素材なしは図形 ＋ 文字）、名前、HP バー（数字とブロック付き）、
## ステータスの列、敵の頭上のインテント。表示値（shown_hp など）は Presenter が再生時に渡す値だけで変わり、モデルを直接見ない。

signal pressed(view: UnitView)
## 照準が付いた / 外れた。見た目（3D の輪郭線・足元のリング）は受け手が描く。
signal targeted_changed(view: UnitView, on: bool)

const PLAYER_COLOR: Color = Color(0.22, 0.38, 0.55)
const RANK_COLORS: Dictionary[EnemyData.Rank, Color] = {
	EnemyData.Rank.NORMAL: Color(0.45, 0.28, 0.26), EnemyData.Rank.ELITE: Color(0.62, 0.2, 0.18),
	EnemyData.Rank.BOSS: Color(0.4, 0.12, 0.3),
}
const STATUS_SIZE: Vector2 = Vector2(40, 40)
## インテントの上下のふわふわ（StS と同じく、頭上でゆっくり揺れる）。
const INTENT_BOB_PX: float = 4.0
const INTENT_BOB_SPEED: float = 2.6
const HP_TWEEN: float = 0.25
const GHOST_DELAY: float = 0.35

var uid: int = -1
var is_player: bool = false
var shown_hp: int = 0
var shown_max_hp: int = 1
var shown_block: int = 0
var dead: bool = false
var targeted: bool = false

var _status_badges: Dictionary[StringName, GlyphBadge] = {}
var _hp_tween: Tween
var _bob_time: float = 0.0

@onready var _intent_row: HBoxContainer = %IntentRow
@onready var _intent_badge: GlyphBadge = %IntentBadge
@onready var _intent_label: Label = %IntentLabel
@onready var _portrait: GlyphBadge = %Portrait
@onready var _name: Label = %NameLabel
@onready var _block: GlyphBadge = %BlockBadge
@onready var _bar: ProgressBar = %Bar
@onready var _ghost: ProgressBar = %Ghost
@onready var _hp_text: Label = %HpText
@onready var _statuses: HFlowContainer = %Statuses


func _ready() -> void:
	_portrait.gui_input.connect(_on_portrait_gui_input)
	set_process(false)


func _process(delta: float) -> void:
	_bob_time += delta
	_intent_badge.position.y = sin(_bob_time * INTENT_BOB_SPEED) * INTENT_BOB_PX


func setup(unit: Combatant) -> void:
	uid = unit.uid
	is_player = unit.is_player()
	_name.text = unit.name
	_portrait.text = unit.name.substr(0, 2) if not is_player else "自"
	_portrait.fill = PLAYER_COLOR if is_player else RANK_COLORS.get(unit.data.rank, Color.GRAY)
	_intent_row.modulate.a = 0.0 if is_player else 1.0
	# 敵ごとに揺れの位相をずらす（並んだ敵が揃って揺れない）。
	_bob_time = float(uid) * 1.7
	set_process(not is_player)
	set_intent(null)
	set_hp(unit.hp, unit.max_hp, false)
	set_block(unit.block)
	dead = false
	modulate.a = 1.0


## 3D のアクターが立ち絵の代わりをする（BattleStage.add_actor から）。図形は描かず、矩形（照準の当たり判定と
## エフェクトの位置）だけをアクターの大きさにする。矩形の下辺中央がアクターの足元になる。
func set_stage_mode(portrait_size: Vector2) -> void:
	_portrait.custom_minimum_size = portrait_size
	_portrait.self_modulate.a = 0.0


func set_hp(hp: int, max_hp: int, animate: bool = true) -> void:
	var dropped := hp < shown_hp
	shown_hp = hp
	shown_max_hp = maxi(max_hp, 1)
	_hp_text.text = "%d/%d" % [hp, max_hp]
	var ratio := 100.0 * hp / shown_max_hp
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	if not animate or not is_inside_tree():
		_bar.value = ratio
		_ghost.value = ratio
		return
	_hp_tween = create_tween().set_parallel(true)
	_hp_tween.tween_property(_bar, "value", ratio, HP_TWEEN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 残像バー：減ったときは少し遅れて追いかける。増えたときは即座に合わせる。
	if dropped:
		_hp_tween.tween_property(_ghost, "value", ratio, HP_TWEEN).set_delay(GHOST_DELAY)
	else:
		_ghost.value = ratio


func set_block(block: int) -> void:
	shown_block = block
	_block.text = str(block)
	_block.modulate.a = 1.0 if block > 0 else 0.0
	_block.tooltip_text = UiText.block_text(block) if block > 0 else ""


func set_status(data: StatusData, stacks: int) -> void:
	var badge: GlyphBadge = _status_badges.get(data.id)
	if badge == null:
		badge = GlyphBadge.new()
		badge.custom_minimum_size = STATUS_SIZE
		badge.shape = GlyphBadge.Shape.ROUNDED
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		_statuses.add_child(badge)
		_status_badges[data.id] = badge
	var count := str(stacks) if data.max_stacks > 1 else ""
	badge.icon = UiGlyphs.status_icon(data)
	if badge.icon != null:
		# 画像 ＋ 右下に層数（StS と同じ）。
		badge.outline_width = 0.0
		badge.icon_ratio = 1.0
		badge.corner_text = count
		badge.custom_minimum_size = STATUS_SIZE
	else:
		badge.setup(UiGlyphs.first_char(data.name) + count, UiGlyphs.status_color(data), GlyphBadge.Shape.ROUNDED)
		badge.custom_minimum_size = Vector2(STATUS_SIZE.x + (14.0 if stacks >= 10 else 0.0) + (14.0 if data.max_stacks > 1 else 0.0), STATUS_SIZE.y)
	badge.tooltip_text = UiText.status_text(data, stacks)


func remove_status(status_id: StringName) -> void:
	var badge: GlyphBadge = _status_badges.get(status_id)
	if badge == null:
		return
	_status_badges.erase(status_id)
	_statuses.remove_child(badge)
	badge.queue_free()


## 全ステータスを置き換える（再生の後の同期）。
func set_statuses(stacks: Array[StatusStack]) -> void:
	var keep: Dictionary[StringName, bool] = {}
	for s in stacks:
		keep[s.data.id] = true
		set_status(s.data, s.stacks)
	for id: StringName in _status_badges.keys():
		if not keep.has(id):
			remove_status(id)


func status_ids() -> Array[StringName]:
	return _status_badges.keys()


## null ならインテントを隠す。
func set_intent(intent: Intent, move_name: String = "") -> void:
	if intent == null or is_player:
		_intent_badge.visible = false
		_intent_label.text = ""
		return
	_intent_badge.visible = true
	_intent_badge.text = UiGlyphs.INTENT_GLYPHS.get(intent.kind, "？")
	_intent_badge.fill = UiGlyphs.INTENT_COLORS.get(intent.kind, Color.GRAY)
	_intent_badge.icon = UiGlyphs.INTENT_ICONS.get(intent.kind)
	_intent_label.text = UiGlyphs.intent_label(intent)
	_intent_badge.tooltip_text = UiText.intent_text(intent, move_name)


func intent_text() -> String:
	return _intent_label.text if _intent_badge.visible else ""


func set_targeted(on: bool) -> void:
	if on == targeted:
		return
	targeted = on
	targeted_changed.emit(self, on)


## 名前・HP バーごと消す（場所は残すので、他の敵の位置は動かない）。
func play_death() -> void:
	dead = true
	set_intent(null)
	set_targeted(false)
	create_tween().tween_property(self, "modulate:a", 0.0, 0.3)


## 立ち絵の画面上の矩形（照準の当たり判定とエフェクトの位置）。
func portrait_rect() -> Rect2:
	return _portrait.get_global_rect()


func hit_point() -> Vector2:
	return portrait_rect().get_center()


func _on_portrait_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)

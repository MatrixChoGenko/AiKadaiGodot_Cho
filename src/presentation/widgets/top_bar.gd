class_name TopBar extends Control
## ⑤ Presentation：トップバー（GameDesign §15.1、U02）。常駐し、画面切り替えで作り直さない。StS2 の HUD に合わせた見た目。
## 帯：キャラ / HP / ゴールド / ポーション枠 / 層 / デッキ（枚数のバッジ）/ 設定（未実装・アイコンだけ）。レリックは帯の下に 1 列。
## ルールは知らず、Main が show_run() で値を渡す。
## 戦闘中もポーションはここに出し、操作は戦闘画面に貸す（lend_potions / reclaim_potions）。
## 戦闘外で HP が変わったら、HP の数字を少しずつ動かす（アクト移行の回復が見える。GameDesign §12.6）。

signal deck_pressed
signal potion_discard_requested(slot: int)

const RELIC_SIZE: Vector2 = Vector2(56, 56)
const HP_TWEEN_SECONDS: float = 0.8
const GOLD_TWEEN_SECONDS: float = 0.8

## 表示中の HP / ゴールド（-1 = まだ出していない。トップバーを隠すと戻る）。
var shown_hp: int = -1
var shown_gold: int = -1
var _hp_tween: Tween
var _gold_tween: Tween

## 戦闘画面に貸している間の操作（無効 = 貸していない。ポーションを捨てるだけ）。
var _lent_actions: Callable = Callable()
var _lent_chosen: Callable = Callable()

@onready var _hp: Label = %HpLabel
@onready var _gold: Label = %GoldLabel
@onready var _floor: Label = %FloorLabel
@onready var _floor_icon: GlyphBadge = %FloorIcon
@onready var _potions: PotionBar = %Potions
@onready var _relics: HBoxContainer = %Relics
@onready var _deck: PileButton = %DeckButton


func _ready() -> void:
	_deck.pressed.connect(deck_pressed.emit)
	_potions.actions_provider = _potion_actions
	_potions.action_chosen.connect(_on_potion_action_chosen)


## ランの状態を表示する。戦闘中は HP とポーションを戦闘側の値から出す。
## 協力プレイでは自分（Party.seat）の値を出す。
func show_run(run: RunController) -> void:
	var s := run.state
	var me := Party.me(run)
	var in_combat := run.combat != null
	var my_seat: PlayerSeat = Party.my_seat(run.combat) if in_combat else null
	var hp := my_seat.unit.hp if in_combat else me.hp
	var max_hp := my_seat.unit.max_hp if in_combat else me.max_hp
	set_hp(hp, max_hp, not in_combat)
	set_gold(me.gold, not in_combat)
	var node := s.current_node()
	_floor.text = str(node.row + 1 if node != null else 0)
	_floor_icon.tooltip_text = "現在地
%s" % UiText.floor_text(run)
	_deck.count = me.deck.size()
	_potions.show_potions(my_seat.potions if in_combat else me.potions.slots)
	_show_relics(me.relics)


## 戦闘画面にポーション枠の操作を貸す。actions：PotionBar.actions_provider と同じ形、chosen：func(slot, action)。
func lend_potions(actions: Callable, chosen: Callable) -> PotionBar:
	_lent_actions = actions
	_lent_chosen = chosen
	return _potions


func reclaim_potions() -> void:
	_lent_actions = Callable()
	_lent_chosen = Callable()


## animate なら表示中の値から hp まで動かす。
func set_hp(hp: int, max_hp: int, animate: bool) -> void:
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	if animate and shown_hp >= 0 and shown_hp != hp:
		_hp_tween = create_tween()
		_hp_tween.tween_method(_show_hp.bind(max_hp), float(shown_hp), float(hp), HP_TWEEN_SECONDS) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_show_hp(hp, max_hp)


func hp_text() -> String:
	return _hp.text


## animate なら表示中の値から gold まで 1 ずつ数える（報酬のゴールドを受け取ったとき。StS2 は +15 を約 0.8 秒）。
func set_gold(gold: int, animate: bool) -> void:
	if _gold_tween != null and _gold_tween.is_valid():
		_gold_tween.kill()
	if animate and shown_gold >= 0 and shown_gold != gold:
		_gold_tween = create_tween()
		_gold_tween.tween_method(_show_gold, float(shown_gold), float(gold), GOLD_TWEEN_SECONDS)
	else:
		_show_gold(gold)


## デッキのボタンの中心（報酬で選んだカードが飛んでいく先）。
func deck_center() -> Vector2:
	return _deck.get_global_rect().get_center()


func _show_gold(value: float) -> void:
	shown_gold = roundi(value)
	_gold.text = str(shown_gold)


func _show_hp(value: float, max_hp: int) -> void:
	shown_hp = roundi(value)
	_hp.text = "%d/%d" % [shown_hp, max_hp]


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		shown_hp = -1
		shown_gold = -1


func _show_relics(relics: Array[RelicSlot]) -> void:
	for child in _relics.get_children():
		_relics.remove_child(child)
		child.queue_free()
	for slot in relics:
		var badge := GlyphBadge.new()
		badge.custom_minimum_size = RELIC_SIZE
		badge.setup(UiGlyphs.first_char(slot.data.name), UiGlyphs.RELIC_COLORS.get(slot.data.rarity, Color.GRAY), GlyphBadge.Shape.ROUNDED)
		badge.icon = UiGlyphs.relic_icon(slot.data)
		if badge.icon != null:
			badge.outline_width = 0.0
			badge.icon_ratio = 1.0
		badge.tooltip_text = UiText.relic_text(slot.data, slot.counter)
		_relics.add_child(badge)


func _potion_actions(slot: int) -> Array:
	if _lent_actions.is_valid():
		return _lent_actions.call(slot)
	return [[PotionBar.ACTION_DISCARD, "捨てる", true]]


func _on_potion_action_chosen(slot: int, action: StringName) -> void:
	if _lent_chosen.is_valid():
		_lent_chosen.call(slot, action)
	elif action == PotionBar.ACTION_DISCARD:
		potion_discard_requested.emit(slot)

class_name CombatController extends RefCounted
## ④ Flow：戦闘のファサード（Architecture §7.3）。UI / テスト / ボットはこれだけを呼ぶ。
## コマンド（play_card など）が唯一の書き込み口。クエリは純粋で、毎フレーム呼んでよい。
## 協力プレイ（GameDesign §21）：コマンドもクエリも最後の引数 seat で席（プレイヤー）を指定する。
## -1 = いまの席（1 人プレイでは常に席 0）。クエリは席を切り替えて計算したあと元に戻す。

signal finished(victory: bool)
signal event_emitted(event: CombatEvent)

var combat: Combat
var _finished_sent: bool = false


## 戦闘を作って始める（第 1 ターンのドローとインテントまで進む）。
static func begin(setup: CombatSetup) -> CombatController:
	var c := from_combat(Combat.create(setup))
	c.start()
	return c


## 作っただけの Combat を包む（テストで開始前に状態を整えるとき用）。start() を呼んで始める。
static func from_combat(p_combat: Combat) -> CombatController:
	var c := CombatController.new()
	c.combat = p_combat
	c.combat.event_emitted.connect(c._on_combat_event)
	return c


func start() -> void:
	combat.start()
	_check_finished()


# —— コマンド ——

func play_card(card: Card, target: Combatant = null, seat: int = -1) -> PlayResult:
	combat.focus_index(seat)
	var r := combat.play_card(card, target)
	_check_finished()
	return r


func use_potion(slot: int, target: Combatant = null, seat: int = -1) -> PlayResult:
	combat.focus_index(seat)
	var r := combat.use_potion(slot, target)
	_check_finished()
	return r


func discard_potion(slot: int, seat: int = -1) -> bool:
	combat.focus_index(seat)
	return combat.discard_potion(slot)


func submit_choice(cards: Array[Card], seat: int = -1) -> bool:
	combat.focus_index(seat)
	var ok := combat.submit_choice(cards)
	_check_finished()
	return ok


func end_turn(seat: int = -1) -> bool:
	combat.focus_index(seat)
	var ok := combat.end_turn()
	_check_finished()
	return ok


## 協力プレイ：ターン終了（Ready）の取り消し。
func cancel_ready(seat: int = -1) -> bool:
	combat.focus_index(seat)
	return combat.cancel_ready()


# —— クエリ ——

func check_card(card: Card, target: Combatant = null, seat: int = -1) -> PlayResult:
	var before := combat.focus_index(seat)
	var r := combat.check_card(card, target)
	combat.focus(before)
	return r


func check_potion(slot: int, target: Combatant = null, seat: int = -1) -> PlayResult:
	var before := combat.focus_index(seat)
	var r := combat.check_potion(slot, target)
	combat.focus(before)
	return r


func needs_target(card: Card) -> bool:
	return card.data.aim == CardData.Aim.ENEMY


func card_text(card: Card, target: Combatant = null, keyword_names: Dictionary = {}, seat: int = -1) -> String:
	var before := combat.focus_index(seat)
	var text := CardText.render(card.data, card, combat, target, keyword_names)
	combat.focus(before)
	return text


func cost_of(card: Card, seat: int = -1) -> int:
	var before := combat.focus_index(seat)
	var n := combat.cost_of(card)
	combat.focus(before)
	return n


func intent_of(enemy: Combatant, seat: int = -1) -> Intent:
	var viewer: Combatant = null
	if seat >= 0 and seat < combat.seats.size():
		viewer = combat.seats[seat].unit
	return combat.intent_of(enemy, viewer)


## 協力プレイ：この席がターン終了（Ready）を押して、ほかの人を待っているか（押し直すと取り消し）。
func is_coop_ready_pending(seat: int) -> bool:
	var s := seat_at(seat)
	if s == null or not combat.is_coop() or combat.is_over():
		return false
	return s.ready and s.is_alive() and combat.turn.phase == TurnState.Phase.PLAYER


func pending_choice() -> CardChoice:
	return combat.pending_choice


## 席（協力プレイ）。範囲外なら null。
func seat_at(index: int) -> PlayerSeat:
	return combat.seats[index] if index >= 0 and index < combat.seats.size() else null


func is_over() -> bool:
	return combat.is_over()


func result() -> CombatResult:
	return combat.result()


func result_for(index: int) -> CombatResult:
	return combat.result_for(index)


func _on_combat_event(e: CombatEvent) -> void:
	event_emitted.emit(e)


func _check_finished() -> void:
	if combat.is_over() and not _finished_sent:
		_finished_sent = true
		finished.emit(combat.outcome == Combat.Outcome.VICTORY)

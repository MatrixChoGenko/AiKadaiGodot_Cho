class_name CombatHarness extends RefCounted
## テスト支援：戦闘を操作して検査する薄いラッパ（Architecture §18.2）。
##   h.play(&"strike", h.enemy(0)); h.end_turn(); assert_eq(h.enemy(0).hp, 44)

var ctl: CombatController
var combat: Combat
var deck_size: int
var events: Array[CombatEvent] = []


func _init(p_ctl: CombatController, p_deck_size: int) -> void:
	ctl = p_ctl
	combat = p_ctl.combat
	deck_size = p_deck_size
	ctl.event_emitted.connect(_on_event)   # ラムダだと self を捕まえて循環参照になる


func _on_event(e: CombatEvent) -> void:
	events.append(e)


func player() -> Combatant:
	return combat.player


func enemy(index: int = 0) -> Combatant:
	return combat.enemies[index]


func hand() -> Array[Card]:
	return combat.piles.hand


func hand_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for c in combat.piles.hand:
		ids.append(c.data.id)
	return ids


## 手札から id のカードを探す（無ければ null）。
func card(id: StringName) -> Card:
	for c in combat.piles.hand:
		if c.data.id == id:
			return c
	return null


## id のカードを手札からプレイする。target が null で対象が必要なら、生きている先頭の敵を選ぶ。
func play(id: StringName, target: Combatant = null) -> PlayResult:
	var c := card(id)
	if c == null:
		return PlayResult.fail(PlayResult.NOT_IN_HAND)
	if target == null and ctl.needs_target(c):
		var alive := combat.alive_enemies()
		target = alive[0] if not alive.is_empty() else null
	return ctl.play_card(c, target)


func end_turn() -> bool:
	return ctl.end_turn()


## 手札の中から id のカードを選んで回答する。
func choose(ids: Array) -> bool:
	var picked: Array[Card] = []
	var choice := ctl.pending_choice()
	if choice == null:
		return false
	for id: StringName in ids:
		for c in choice.candidates:
			if c.data.id == id and not picked.has(c):
				picked.append(c)
				break
	return ctl.submit_choice(picked)


func add_status(unit: Combatant, status_id: StringName, stacks: int) -> void:
	combat.apply_status(unit, unit, ContentKit.status(status_id), stacks)


func stacks(unit: Combatant, status_id: StringName) -> int:
	var s := unit.statuses.find_id(status_id)
	return s.stacks if s != null else 0


func events_of(kind: CombatEvent.Kind) -> Array[CombatEvent]:
	var result: Array[CombatEvent] = []
	for e in events:
		if e.kind == kind:
			result.append(e)
	return result


## カード枚数の保存：デッキ + 生成したカード == 全部の山の合計（重複なし）。
func cards_conserved() -> bool:
	var all := combat.piles.all_cards()
	var unique: Dictionary = {}
	for c in all:
		unique[c] = true
	return unique.size() == all.size() and all.size() == deck_size + combat.created_count

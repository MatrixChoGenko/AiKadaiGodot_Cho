class_name FirstCardOfTypeEcho extends CombatBehavior
## 毎ターン最初にプレイする type_filter のカードがもう一度解決される（反響の護符）。PLAY_COUNT + CARD_PLAYED + TURN_START。

@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = CardData.TYPE_BIT_ATTACK


func hooks() -> int:
	return Hook.PLAY_COUNT | Hook.CARD_PLAYED | Hook.TURN_START


func modify(_hook: Hook, host: BehaviorHost, _combat: Combat, calc: RefCounted) -> void:
	var c := calc as HookCalc
	if host.counter == 0 and c.card != null and c.card.matches(type_filter):
		c.amount += 1


func on_event(hook: Hook, host: BehaviorHost, combat: Combat, payload: Variant) -> void:
	if hook == Hook.TURN_START:
		if payload == host.owner:
			host.counter = 0
	elif host.counter == 0 and (payload as Card).matches(type_filter):
		host.counter = 1
		combat.notify_triggered(host)

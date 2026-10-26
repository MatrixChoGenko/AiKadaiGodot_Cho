class_name NegateDebuff extends CombatBehavior
## 次に付与されるデバフを打ち消し、スタック −1（アーティファクト）。STATUS_APPLY / EARLY。


func hooks() -> int:
	return Hook.STATUS_APPLY


func priority() -> int:
	return Priority.EARLY


func modify(_hook: Hook, host: BehaviorHost, combat: Combat, calc: RefCounted) -> void:
	var c := calc as HookCalc
	if c.cancelled or c.target != host.owner or c.amount <= 0 or c.status.polarity != StatusData.Polarity.DEBUFF:
		return
	c.cancelled = true
	if not c.preview:
		combat.notify_triggered(host)
		combat.reduce_stacks(host as StatusStack, 1)

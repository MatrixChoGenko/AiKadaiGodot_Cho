class_name VictoryRewards extends CombatBehavior
## 戦闘に勝利したとき HP を heal 回復し、gold を得る（燃える血、道具箱）。COMBAT_END（payload = 勝利したか）。

@export var heal: int = 0
@export var gold: int = 0


func hooks() -> int:
	return Hook.COMBAT_END


func on_event(_hook: Hook, host: BehaviorHost, combat: Combat, payload: Variant) -> void:
	if payload != true:
		return
	combat.notify_triggered(host)
	if heal > 0:
		combat.heal(host.owner, heal)
	combat.seat_of(host.owner).gold_gained += gold

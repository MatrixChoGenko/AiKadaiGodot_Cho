class_name GrantStatusOnCombatStart extends CombatBehavior
## 戦闘開始時に status を stacks 得る（金剛杵、青銅の鱗、アーティファクトトーテム、トカゲの尻尾）。COMBAT_START。

@export var status: StatusData
@export var stacks: int = 1


func hooks() -> int:
	return Hook.COMBAT_START


func on_event(_hook: Hook, host: BehaviorHost, combat: Combat, _payload: Variant) -> void:
	combat.notify_triggered(host)
	combat.apply_status(host.owner, host.owner, status, stacks)

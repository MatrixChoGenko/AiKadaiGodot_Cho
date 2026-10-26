class_name GrantStatusOnTurnStart extends CombatBehavior
## 持ち主のターン開始時に status をスタック × per_stack 得る（悪魔化）。TURN_START。

@export var status: StatusData
@export var per_stack: int = 1


func hooks() -> int:
	return Hook.TURN_START


func on_event(_hook: Hook, host: BehaviorHost, combat: Combat, payload: Variant) -> void:
	if payload != host.owner:
		return
	combat.notify_triggered(host)
	combat.apply_status(host.owner, host.owner, status, host.stacks * per_stack)

class_name HealOverTime extends CombatBehavior
## プレイヤーのターン終了時にスタック分の HP を回復し、その後スタック −decrement（再生）。
## スタックはこの Behavior だけが減らす（StatusData.decay は NONE にする）。

@export var decrement: int = 1


func hooks() -> int:
	return Hook.TURN_END


func on_event(_hook: Hook, host: BehaviorHost, combat: Combat, _payload: Variant) -> void:
	var stack := host as StatusStack
	combat.notify_triggered(stack)
	combat.heal(stack.owner, stack.stacks)
	combat.reduce_stacks(stack, decrement)

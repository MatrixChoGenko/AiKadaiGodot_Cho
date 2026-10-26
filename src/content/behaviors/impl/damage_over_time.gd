class_name DamageOverTime extends CombatBehavior
## プレイヤーのターン終了時にブロックを無視してスタック分のダメージを受け、その後スタック −decrement（毒）。
## 敵に付いた毒もプレイヤーのターン終了時に発動する（GameDesign 付録 C の C4）。
## スタックはこの Behavior だけが減らす（StatusData.decay は NONE にする）。

@export var decrement: int = 1


func hooks() -> int:
	return Hook.TURN_END


func on_event(_hook: Hook, host: BehaviorHost, combat: Combat, _payload: Variant) -> void:
	var stack := host as StatusStack
	combat.notify_triggered(stack)
	var calc := DamageCalc.new(stack.stacks, DamageEffect.Kind.STATUS, null, stack.owner)
	calc.pierce_block = true
	combat.deal_damage(calc)
	combat.reduce_stacks(stack, decrement)

class_name AllOfCondition extends Condition
## すべての子条件が成立する。

@export var conditions: Array[Condition] = []


func _test(ctx: EffectContext, subject: Combatant) -> bool:
	for c in conditions:
		if not c.test(ctx, subject):
			return false
	return true

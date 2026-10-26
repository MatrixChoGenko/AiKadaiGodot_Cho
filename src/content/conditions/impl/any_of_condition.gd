class_name AnyOfCondition extends Condition
## いずれかの子条件が成立する。

@export var conditions: Array[Condition] = []


func _test(ctx: EffectContext, subject: Combatant) -> bool:
	for c in conditions:
		if c.test(ctx, subject):
			return true
	return false

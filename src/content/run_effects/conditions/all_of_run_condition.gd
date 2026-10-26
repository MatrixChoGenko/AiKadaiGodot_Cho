class_name AllOfRunCondition extends RunCondition
## すべての子条件が成立する。

@export var conditions: Array[RunCondition] = []


func _test(ctx: RunEffectContext) -> bool:
	for c in conditions:
		if c != null and not c.test(ctx):
			return false
	return true

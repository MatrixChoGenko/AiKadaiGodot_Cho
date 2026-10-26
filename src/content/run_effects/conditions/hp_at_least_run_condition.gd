class_name HpAtLeastRunCondition extends RunCondition
## HP が value 以上。

@export var value: int = 1


func _test(ctx: RunEffectContext) -> bool:
	return ctx.state.hp >= value

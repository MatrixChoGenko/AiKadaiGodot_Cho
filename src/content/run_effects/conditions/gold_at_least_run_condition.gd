class_name GoldAtLeastRunCondition extends RunCondition
## ゴールドが value 以上。

@export var value: int = 0


func _test(ctx: RunEffectContext) -> bool:
	return ctx.state.gold >= value

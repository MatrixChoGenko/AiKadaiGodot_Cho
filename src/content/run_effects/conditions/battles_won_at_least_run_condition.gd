class_name BattlesWonAtLeastRunCondition extends RunCondition
## 勝利数が value 以上。

@export var value: int = 1


func _test(ctx: RunEffectContext) -> bool:
	return ctx.state.battles_won >= value

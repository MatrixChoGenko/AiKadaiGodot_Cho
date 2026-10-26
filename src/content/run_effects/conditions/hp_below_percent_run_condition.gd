class_name HpBelowPercentRunCondition extends RunCondition
## HP が最大 HP の percent% 未満。

@export_range(1, 100) var percent: int = 50


func _test(ctx: RunEffectContext) -> bool:
	return ctx.state.hp * 100 < ctx.state.max_hp * percent

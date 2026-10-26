class_name GoldRunEffect extends RunEffect
## ゴールドを増減する。足りないときに選ばせないのは EventOption.requires（GoldAtLeastRunCondition）で行う。

@export var amount: int = 0


func apply(ctx: RunEffectContext) -> void:
	ctx.state.change_gold(amount)

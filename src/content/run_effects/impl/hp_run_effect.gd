class_name HpRunEffect extends RunEffect
## HP を増減する（定数、または最大 HP の %）。HP は 1 未満にならない。

@export var amount: int = 0
## true なら amount を最大 HP に対する % として扱う。
@export var percent_of_max: bool = false


func apply(ctx: RunEffectContext) -> void:
	var delta := amount
	if percent_of_max:
		delta = int(ctx.state.max_hp * amount / 100.0)   # 0 方向に切り捨て
	if delta < 0:
		ctx.state.lose_hp_nonlethal(-delta)
	else:
		ctx.state.change_hp(delta)

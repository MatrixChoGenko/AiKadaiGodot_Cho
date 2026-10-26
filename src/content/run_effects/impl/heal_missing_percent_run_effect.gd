class_name HealMissingPercentRunEffect extends RunEffect
## 失った HP の percent% を回復する（切り捨て）。

@export_range(0, 100) var percent: int = 0


func apply(ctx: RunEffectContext) -> void:
	ctx.state.change_hp(int((ctx.state.max_hp - ctx.state.hp) * percent / 100.0))

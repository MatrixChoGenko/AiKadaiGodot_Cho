class_name PotionSlotsRunEffect extends RunEffect
## ポーション枠の数を増減する。

@export var delta: int = 1


func apply(ctx: RunEffectContext) -> void:
	ctx.state.potions.resize(ctx.state.potions.slots.size() + delta)

class_name MaxHpRunEffect extends RunEffect
## 最大 HP を増減する。heal_too なら増えた分だけ現在の HP も回復する。

@export var amount: int = 0
@export var heal_too: bool = true


func apply(ctx: RunEffectContext) -> void:
	ctx.state.change_max_hp(amount)
	if heal_too and amount > 0:
		ctx.state.change_hp(amount)

class_name RandomRunEffect extends RunEffect
## ランダム分岐（賭け）。percent% の確率で then、そうでなければ otherwise。乱数は event ストリーム。

@export_range(0, 100) var percent: int = 50
@export var then: Array[RunEffect] = []
@export var otherwise: Array[RunEffect] = []


func children() -> Array[RunEffect]:
	var all: Array[RunEffect] = []
	all.append_array(then)
	all.append_array(otherwise)
	return all


func apply(ctx: RunEffectContext) -> void:
	ctx.apply_all(then if ctx.rng().chance(RunEffectContext.STREAM, percent) else otherwise)

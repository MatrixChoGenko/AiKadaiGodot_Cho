class_name SequenceEffect extends CardEffect
## コンビネータ：子効果を順に実行する。

@export var effects: Array[CardEffect] = []


func apply(ctx: EffectContext) -> void:
	ctx.combat.push_effects(effects, ctx.child())


func preview(ctx: EffectContext, out: Preview) -> void:
	for e in effects:
		e.preview(ctx, out)


func children() -> Array[CardEffect]:
	return effects

class_name HealEffect extends CardEffect
## HP を回復する（GameDesign §7.1 heal）。target が null なら発動者自身。

@export var amount: ValueSource


func apply(ctx: EffectContext) -> void:
	var n := amount.evaluate(ctx)
	for u in units_or_source(ctx):
		ctx.combat.heal(u, n)


func preview(ctx: EffectContext, out: Preview) -> void:
	var n := amount.evaluate(ctx)
	out.set_label(label, n, n)
	if out.muted == 0:
		out.buffs = true

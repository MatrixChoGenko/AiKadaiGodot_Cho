class_name BlockEffect extends CardEffect
## ブロックを得る（GameDesign §7.1 block）。target が null なら発動者自身。

@export var amount: ValueSource


func apply(ctx: EffectContext) -> void:
	var n := amount.evaluate(ctx)
	for u in units_or_source(ctx):
		ctx.combat.gain_block(u, n)


func preview(ctx: EffectContext, out: Preview) -> void:
	var base := amount.evaluate(ctx)
	var value := base
	if ctx.combat != null and ctx.source != null:
		value = ctx.combat.gain_block(ctx.source, base, true)
	out.set_label(label, value, base)
	if out.muted == 0:
		out.block += value

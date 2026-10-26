class_name LoseHpEffect extends CardEffect
## HP を失う（ブロック無視・補正なしの HP 喪失。供物、火傷、血の契約）。target が null なら発動者自身。

@export var amount: ValueSource


func apply(ctx: EffectContext) -> void:
	var n := amount.evaluate(ctx)
	for u in units_or_source(ctx):
		ctx.combat.lose_hp(u, n, ctx.source)


func preview(ctx: EffectContext, out: Preview) -> void:
	var n := amount.evaluate(ctx)
	out.set_label(label, n, n)

class_name GainEnergyEffect extends CardEffect
## エネルギーを増減する（GameDesign §7.1 energy）。プレイヤーが発動したときだけ効く。

@export var amount: ValueSource


func apply(ctx: EffectContext) -> void:
	if ctx.source != null and ctx.source.is_player():
		ctx.combat.gain_energy(amount.evaluate(ctx))


func preview(ctx: EffectContext, out: Preview) -> void:
	var n := amount.evaluate(ctx)
	out.set_label(label, n, n)

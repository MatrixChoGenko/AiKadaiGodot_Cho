class_name ApplyStatusEffect extends CardEffect
## ステータスを付与する（バフ / デバフ共通。GameDesign §7.1 applyStatus）。

@export var status: StatusData
@export var stacks: ValueSource


func apply(ctx: EffectContext) -> void:
	var n := stacks.evaluate(ctx)
	for u in units_or_source(ctx):
		ctx.combat.apply_status(ctx.source, u, status, n)


func preview(ctx: EffectContext, out: Preview) -> void:
	var n := stacks.evaluate(ctx)
	out.set_label(label, n, n)
	if out.muted > 0:
		return
	if status.polarity == StatusData.Polarity.DEBUFF:
		out.debuffs = true
	else:
		out.buffs = true

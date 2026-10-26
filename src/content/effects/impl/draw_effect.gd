class_name DrawEffect extends CardEffect
## カードを引く（GameDesign §7.1 draw）。プレイヤーが発動したときだけ効く。

@export var count: ValueSource


func apply(ctx: EffectContext) -> void:
	if ctx.source != null and ctx.source.is_player():
		ctx.combat.draw_cards(count.evaluate(ctx))


func preview(ctx: EffectContext, out: Preview) -> void:
	var n := count.evaluate(ctx)
	out.set_label(label, n, n)

class_name RemoveStatusesEffect extends CardEffect
## 指定した極性のステータスをすべて取り除く（死霊術師（guardian）の第 2 フェーズ移行で「自分のデバフを解除」）。

@export var polarity: StatusData.Polarity = StatusData.Polarity.DEBUFF


func apply(ctx: EffectContext) -> void:
	for u in units_or_source(ctx):
		ctx.combat.remove_statuses(u, polarity)


func preview(_ctx: EffectContext, out: Preview) -> void:
	if out.muted == 0:
		out.buffs = true

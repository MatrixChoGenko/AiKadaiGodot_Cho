class_name SpreadStatusEffect extends CardEffect
## 選んだ対象のステータスを、spread_to のユニットに拡散する（GameDesign §7.1 spreadStatus）。
## target = 拡散元、spread_to = 拡散先。付与量 = 拡散元のスタック × percent / 100（切り捨て）。

@export var status: StatusData
@export var spread_to: TargetRule
@export_range(0, 1000) var percent: int = 50
## 既にそのステータスを持つユニットには付与しない。
@export var skip_if_has: bool = false


func apply(ctx: EffectContext) -> void:
	for origin in units_or_source(ctx):
		var n := origin.stacks_of(status) * percent / 100
		if n <= 0:
			continue
		for u in spread_to.resolve(ctx):
			if u == origin or (skip_if_has and u.stacks_of(status) > 0):
				continue
			ctx.combat.apply_status(ctx.source, u, status, n)


func preview(_ctx: EffectContext, out: Preview) -> void:
	if out.muted == 0 and status.polarity == StatusData.Polarity.DEBUFF:
		out.debuffs = true

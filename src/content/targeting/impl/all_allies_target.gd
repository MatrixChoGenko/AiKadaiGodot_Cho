class_name AllAlliesTarget extends TargetRule
## 発動者から見た味方全体（発動者を含む。除くなら exclude_self）。


func _resolve(ctx: EffectContext) -> Array[Combatant]:
	return filter(ctx, ctx.combat.allies_of(ctx.source))

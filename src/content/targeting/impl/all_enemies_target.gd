class_name AllEnemiesTarget extends TargetRule
## 発動者から見た敵全体（生存者のみ）。


func _resolve(ctx: EffectContext) -> Array[Combatant]:
	return filter(ctx, ctx.combat.opponents_of(ctx.source))

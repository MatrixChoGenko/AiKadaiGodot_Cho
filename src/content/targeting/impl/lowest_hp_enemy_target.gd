class_name LowestHpEnemyTarget extends TargetRule
## HP が最も低い敵（同値なら左から）。


func _resolve(ctx: EffectContext) -> Array[Combatant]:
	var best: Combatant = null
	for u in filter(ctx, ctx.combat.opponents_of(ctx.source)):
		if best == null or u.hp < best.hp:
			best = u
	var units: Array[Combatant] = []
	if best != null:
		units.append(best)
	return units

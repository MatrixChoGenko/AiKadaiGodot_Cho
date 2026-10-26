class_name SelfTarget extends TargetRule
## 発動者自身。


func _resolve(ctx: EffectContext) -> Array[Combatant]:
	var units: Array[Combatant] = [ctx.source]
	return filter(ctx, units)

class_name EveryoneTarget extends TargetRule
## 生存している全ユニット。


func _resolve(ctx: EffectContext) -> Array[Combatant]:
	return filter(ctx, ctx.combat.alive_units())

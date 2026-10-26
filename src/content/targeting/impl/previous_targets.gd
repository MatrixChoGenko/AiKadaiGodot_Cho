class_name PreviousTargets extends TargetRule
## 直前の効果が解決した対象。


func _resolve(ctx: EffectContext) -> Array[Combatant]:
	return filter(ctx, ctx.previous_targets)

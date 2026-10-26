class_name CurrentEnergyValue extends ValueSource
## 現在のエネルギー。


func _raw(ctx: EffectContext) -> int:
	return ctx.combat.turn.energy if ctx.combat != null else 0

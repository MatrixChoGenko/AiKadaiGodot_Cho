class_name TurnNumberValue extends ValueSource
## 現在のターン数（1 始まり）。


func _raw(ctx: EffectContext) -> int:
	return ctx.combat.turn.number if ctx.combat != null else 0

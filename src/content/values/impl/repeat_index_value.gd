class_name RepeatIndexValue extends ValueSource
## RepeatEffect の中での繰り返しの番号（0 始まり）。


func _raw(ctx: EffectContext) -> int:
	return ctx.repeat_index

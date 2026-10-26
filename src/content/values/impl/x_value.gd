class_name XValue extends ValueSource
## X コストで実際に支払ったエネルギー（プレビューでは現在のエネルギー）。


func _raw(ctx: EffectContext) -> int:
	return ctx.x

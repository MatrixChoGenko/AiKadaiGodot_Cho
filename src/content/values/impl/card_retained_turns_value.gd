class_name CardRetainedTurnsValue extends ValueSource
## このカードの保留ターン数（手札に入ると 0 に戻る）。


func _raw(ctx: EffectContext) -> int:
	return ctx.card.retained_turns if ctx.card != null else 0

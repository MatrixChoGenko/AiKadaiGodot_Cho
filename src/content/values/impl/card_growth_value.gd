class_name CardGrowthValue extends ValueSource
## このカードのこの戦闘中の成長値（GrowCardEffect で増える）。


func _raw(ctx: EffectContext) -> int:
	return ctx.card.growth if ctx.card != null else 0

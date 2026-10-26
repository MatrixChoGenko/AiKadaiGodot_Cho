class_name GrowCardEffect extends CardEffect
## カードの成長値（この戦闘中）を増やす（GameDesign §7.1 modifyCardValue）。値の出所 CardGrowthValue で読む。

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	if ctx.card != null:
		ctx.card.growth += amount
		ctx.combat.touch_card(ctx.card)

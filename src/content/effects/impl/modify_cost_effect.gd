class_name ModifyCostEffect extends CardEffect
## カードのコストを変更する（GameDesign §7.1 modifyCardCost）。

enum Scope { HAND, SELF }

@export var scope: Scope = Scope.HAND
@export var delta: int = -1
## true = このターンだけ。false = この戦闘中ずっと。
@export var this_turn_only: bool = true


func apply(ctx: EffectContext) -> void:
	var cards: Array[Card] = []
	if scope == Scope.HAND:
		cards = ctx.combat.piles.hand.duplicate()
	elif ctx.card != null:
		cards.append(ctx.card)
	for c in cards:
		if this_turn_only:
			c.cost_delta_turn += delta
		else:
			c.cost_delta_combat += delta
		ctx.combat.touch_card(c)

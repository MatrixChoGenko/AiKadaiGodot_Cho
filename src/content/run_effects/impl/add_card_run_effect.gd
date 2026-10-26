class_name AddCardRunEffect extends RunEffect
## デッキにカードを加える。指定のカード、またはレアリティでランダム。
## choose_from > 0 なら候補をその枚数だけ出し、プレイヤーが 1 枚選ぶ（カード選択リクエストになる）。

enum Pool { FIXED, ANY_RARITY, COMMON, UNCOMMON, RARE }

@export var pool: Pool = Pool.FIXED
## pool = FIXED のときのカード。
@export var card: CardData
@export_range(1, 10) var count: int = 1
@export_range(0, 10) var choose_from: int = 0


func apply(ctx: RunEffectContext) -> void:
	if pool == Pool.FIXED:
		if card != null:
			for i in count:
				ctx.state.deck.add(card)
		return
	var candidates := _pool_cards(ctx)
	for i in count:
		if choose_from > 0:
			var offers := ctx.loot.random_cards(RunEffectContext.STREAM, candidates, choose_from)
			if not offers.is_empty():
				ctx.requests.append(RunChoiceRequest.pick(offers))
		else:
			var picked := ctx.loot.random_cards(RunEffectContext.STREAM, candidates, 1)
			if not picked.is_empty():
				ctx.state.deck.add(picked[0])


## 「任意のレアリティ」は報酬プール全体から重みなしで選ぶ（付録 C の C35）。
func _pool_cards(ctx: RunEffectContext) -> Array[CardData]:
	match pool:
		Pool.COMMON:
			return ctx.content.cards_by_rarity(CardData.Rarity.COMMON)
		Pool.UNCOMMON:
			return ctx.content.cards_by_rarity(CardData.Rarity.UNCOMMON)
		Pool.RARE:
			return ctx.content.cards_by_rarity(CardData.Rarity.RARE)
		_:
			return ctx.content.reward_pool()

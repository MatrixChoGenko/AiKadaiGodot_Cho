class_name DeckSizeAtLeastRunCondition extends RunCondition
## デッキの枚数が value 以上。

@export var value: int = 1


func _test(ctx: RunEffectContext) -> bool:
	return ctx.state.deck.size() >= value

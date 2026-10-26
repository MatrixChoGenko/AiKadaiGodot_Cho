class_name HasCardRunCondition extends RunCondition
## 特定のカード（アップグレード版も含む）をデッキに持っている。

@export var card: CardData


func _test(ctx: RunEffectContext) -> bool:
	# card とそのアップグレード版（の連鎖）のどれかを持っていれば成立。
	var ids: Array[StringName] = []
	var c := card
	while c != null and not ids.has(c.id):
		ids.append(c.id)
		c = c.upgraded
	for owned in ctx.state.deck.cards:
		if ids.has(owned.data.id):
			return true
	return false

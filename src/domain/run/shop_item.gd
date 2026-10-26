class_name ShopItem extends RefCounted
## ③ Domain：ショップの商品 1 つ。

enum Kind { CARD, RELIC, POTION }

var kind: Kind
var card: CardData
var relic: RelicData
var potion: PotionData
var price: int = 0
var sold: bool = false


func content_id() -> StringName:
	match kind:
		Kind.CARD:
			return card.id
		Kind.RELIC:
			return relic.id
		_:
			return potion.id

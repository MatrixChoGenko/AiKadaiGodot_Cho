class_name RewardItem extends RefCounted
## ③ Domain：報酬の 1 行（ゴールド / カード 3 択 / レリック / ポーション）。

## 値はセーブに使うので、既存の値の順序を変えない。
enum Kind { GOLD, CARDS, RELIC, POTION }

var kind: Kind
var gold: int = 0
## CARDS の候補（この中から 1 枚を選ぶ。選ばずに離れてもよい）。
var cards: Array[CardData] = []
var relic: RelicData
var potion: PotionData
var taken: bool = false


static func of_gold(amount: int) -> RewardItem:
	var r := RewardItem.new()
	r.kind = Kind.GOLD
	r.gold = amount
	return r


static func of_cards(list: Array[CardData]) -> RewardItem:
	var r := RewardItem.new()
	r.kind = Kind.CARDS
	r.cards = list
	return r


static func of_relic(data: RelicData) -> RewardItem:
	var r := RewardItem.new()
	r.kind = Kind.RELIC
	r.relic = data
	return r


static func of_potion(data: PotionData) -> RewardItem:
	var r := RewardItem.new()
	r.kind = Kind.POTION
	r.potion = data
	return r

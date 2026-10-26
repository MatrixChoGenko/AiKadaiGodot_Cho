class_name Deck extends RefCounted
## ③ Domain：ラン中のデッキ（Array[Card] + uid の採番器）。戦闘ではこの Card オブジェクトがそのまま山を移動する。

var cards: Array[Card] = []
## 次に作るカードの uid。戦闘中の一時カードは Combat が deck の最大 uid + 1 から採番するので、ここは永続カード専用。
var next_uid: int = 1


func add(data: CardData) -> Card:
	var card := Card.new(next_uid, data)
	next_uid += 1
	cards.append(card)
	return card


func remove(card: Card) -> bool:
	var i := cards.find(card)
	if i < 0:
		return false
	cards.remove_at(i)
	return true


func has(card: Card) -> bool:
	return cards.has(card)


func find_uid(uid: int) -> Card:
	for c in cards:
		if c.uid == uid:
			return c
	return null


func upgradable() -> Array[Card]:
	var result: Array[Card] = []
	for c in cards:
		if c.can_upgrade():
			result.append(c)
	return result


func size() -> int:
	return cards.size()

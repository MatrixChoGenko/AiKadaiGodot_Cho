class_name Piles extends RefCounted
## ③ Domain：戦闘中の山（山札 / 手札 / 捨て札 / 廃棄札）と、場に出たパワー。
## 山札の一番上 = 配列の末尾。カードの移動とトリガーは Combat が行い、ここは入れ物と検索だけ。

var draw: Array[Card] = []
var hand: Array[Card] = []
var discard: Array[Card] = []
var exhaust: Array[Card] = []
## プレイされて戦闘から除外されたパワー（カード枚数の保存の検査に使う）。
var powers: Array[Card] = []
## プレイ中で、どの山にもないカード。
var in_play: Array[Card] = []


func pile(id: Pile.Id) -> Array[Card]:
	match id:
		Pile.Id.DRAW:
			return draw
		Pile.Id.HAND:
			return hand
		Pile.Id.DISCARD:
			return discard
		_:
			return exhaust


## カードを今ある場所から取り除く。見つかれば true。
func take(card: Card) -> bool:
	for arr: Array[Card] in [hand, draw, discard, exhaust, in_play, powers]:
		var i := arr.find(card)
		if i >= 0:
			arr.remove_at(i)
			return true
	return false


func location_of(card: Card) -> String:
	if card in hand:
		return "hand"
	if card in draw:
		return "draw"
	if card in discard:
		return "discard"
	if card in exhaust:
		return "exhaust"
	if card in in_play:
		return "in_play"
	if card in powers:
		return "powers"
	return "none"


func all_cards() -> Array[Card]:
	var result: Array[Card] = []
	for arr: Array[Card] in [draw, hand, discard, exhaust, powers, in_play]:
		result.append_array(arr)
	return result


func count_in_hand(type_filter: int, exclude: Card = null) -> int:
	var n := 0
	for c in hand:
		if c != exclude and c.matches(type_filter):
			n += 1
	return n

class_name CardChoice extends RefCounted
## ③ Domain：プレイヤーのカード選択の要求（GameDesign §5.9 / Architecture §7.10）。

## 候補の元の山と種類のフィルタ。候補は実行時に作り直す（Combat.refresh_choice_candidates）。
var source: Pile.Id = Pile.Id.HAND
var type_filter: int = 0
## 候補から除くカード（プレイ中のカード自身など）。
var exclude: Card
var candidates: Array[Card] = []
var min_count: int = 1
var max_count: int = 1
var action: ChooseCardsEffect.Action = ChooseCardsEffect.Action.DISCARD
var cancellable: bool = false
var prompt: String = ""
var ctx: EffectContext
## 選択が済んだ（ChooseCardsAction が再実行されたときに DONE を返すため）。
var resolved: bool = false


## cards が有効な回答か（候補内・重複なし・枚数の範囲内）。
func accepts(cards: Array[Card]) -> bool:
	if cards.size() < min_count or cards.size() > max_count:
		return false
	var seen: Dictionary = {}
	for c in cards:
		if not c in candidates or seen.has(c):
			return false
		seen[c] = true
	return true

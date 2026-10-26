class_name PlayerSeat extends RefCounted
## ③ Domain：戦闘中のプレイヤー 1 人分の持ち物（協力プレイ。GameDesign §21）。
## 1 人プレイでは席は 1 つだけ。Combat は「いま処理している席」（Combat.seat）を通して
## player / piles / turn / potions / relics を読むので、効果やカードのコードは席を意識しない。

var index: int = 0
var unit: Combatant
var piles: Piles = Piles.new()
## エネルギーとこのターンのプレイ統計は席ごと。フェーズとターン数は全席で同じ値（Combat.set_phase が揃える）。
var turn: TurnState = TurnState.new()
## 順序 = 発動順。RunState のものをそのまま使う（カウンタを書き戻すため）。
var relics: Array[RelicSlot] = []
## ポーション枠。空きは null。
var potions: Array[PotionData] = []
var energy_per_turn: int = 3
var draw_per_turn: int = 5
var gold_gained: int = 0
## ターン終了を押した（全員が押したら敵のターン）。倒れた席は常に押した扱い。
var ready: bool = false
## 開戦時に山札へ入れるカード。
var deck: Array[Card] = []
var keep_deck_order: bool = false


func is_alive() -> bool:
	return unit != null and unit.is_alive()

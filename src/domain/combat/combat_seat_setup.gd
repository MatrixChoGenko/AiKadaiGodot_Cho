class_name CombatSeatSetup extends RefCounted
## ③ Domain：協力プレイの戦闘で、プレイヤー 1 人分の入力（RunController が PlayerState から作る）。
## 1 人プレイでは使わず、CombatSetup の player_* などのフィールドがそのまま席 0 になる。

var name: String = "プレイヤー"
var hp: int = 80
var max_hp: int = 80
var energy_per_turn: int = 3
var draw_per_turn: int = 5
var deck: Array[Card] = []
var relics: Array[RelicSlot] = []
## ポーション枠。空きは null。
var potions: Array[PotionData] = []

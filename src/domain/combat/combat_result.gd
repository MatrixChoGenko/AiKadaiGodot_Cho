class_name CombatResult extends RefCounted
## ③ Domain：戦闘の結果。RunController が RunState に書き戻す。

var victory: bool = false
var hp: int = 0
var max_hp: int = 0
## 戦闘中に得たゴールド（道具箱など）。
var gold_gained: int = 0
var potions: Array[PotionData] = []
var turns: int = 0
## 異常終了（無限ループのガードなど）。
var aborted: bool = false
## 協力プレイ：この席のプレイヤーが戦闘中に倒れた（勝利なら HP 1 で復活する。GameDesign §21）。
var downed: bool = false

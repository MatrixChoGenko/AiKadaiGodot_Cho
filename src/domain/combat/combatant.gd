class_name Combatant extends RefCounted
## ③ Domain：戦闘中のユニット（プレイヤー / 敵）。HP・ブロック・ステータスを持つ。
## HP とブロックの変更は Combat の API（deal_damage / gain_block / heal …）だけが行う。

enum Side { PLAYER, ENEMY }

var uid: int
var side: Side
var name: String
var hp: int
var max_hp: int
var block: int = 0
var statuses: StatusSet = StatusSet.new()
## 敵のみ。
var data: EnemyData
var mind: EnemyMind
## 死亡処理（DeathAction）が済んだ。
var dead: bool = false


## p_side は Side の値（循環参照の中では列挙型の引数の型が解決できないため int で受ける）。
func _init(p_uid: int, p_side: int, p_name: String, p_hp: int, p_max_hp: int) -> void:
	uid = p_uid
	side = p_side as Side
	name = p_name
	hp = p_hp
	max_hp = p_max_hp


func is_alive() -> bool:
	return hp > 0 and not dead


func is_player() -> bool:
	return side == Side.PLAYER


func stacks_of(status: StatusData) -> int:
	return statuses.stacks_of(status)


func _to_string() -> String:
	return "%s#%d(%d/%d+%d)" % [name, uid, hp, max_hp, block]

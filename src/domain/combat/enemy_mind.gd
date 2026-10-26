class_name EnemyMind extends RefCounted
## ③ Domain：敵ごとの実行時の AI 状態（Architecture §9.1）。AI の Resource はステートレスなので、状態はすべてここ。

## 実行した行動の id（古い順）。
var history: Array[StringName] = []
## 固定シーケンス（opening）の次の位置。
var sequence_step: int = 0
## 現在のフェーズ（1 始まり）。
var phase: int = 1
## 行動 id → この戦闘での使用回数。
var uses: Dictionary[StringName, int] = {}
## 行動 id → 使えるようになるまでの残りターン。
var cooldowns: Dictionary[StringName, int] = {}
## このターンに実行する行動（インテントの元）。
var current_move: EnemyMove


## 行動 id が末尾に何回続いているか。
func trailing_count(move_id: StringName) -> int:
	var n := 0
	for i in range(history.size() - 1, -1, -1):
		if history[i] != move_id:
			break
		n += 1
	return n


func record(move: EnemyMove) -> void:
	history.append(move.id)
	uses[move.id] = uses.get(move.id, 0) + 1
	for key in cooldowns.keys():
		cooldowns[key] = cooldowns[key] - 1
		if cooldowns[key] <= 0:
			cooldowns.erase(key)
	if move.cooldown > 0:
		cooldowns[move.id] = move.cooldown + 1   # 次の record で 1 減るので +1

class_name PotionBelt extends RefCounted
## ③ Domain：ポーション枠（GameDesign §10）。slots の空きは null。戦闘では slots の複製を Combat に渡し、結果を書き戻す。

var slots: Array[PotionData] = []


func _init(count: int = 0) -> void:
	resize(count)


## 枠の数を変える。減らすときは後ろの枠のポーションから失われる。
func resize(count: int) -> void:
	count = maxi(count, 0)
	while slots.size() > count:
		slots.pop_back()
	while slots.size() < count:
		slots.append(null)


## 空いている最初の枠に入れる。いっぱいなら false（GameDesign §10：得られない）。
func add(potion: PotionData) -> bool:
	var i := slots.find(null)
	if i < 0:
		return false
	slots[i] = potion
	return true


func remove(slot: int) -> PotionData:
	if slot < 0 or slot >= slots.size():
		return null
	var p := slots[slot]
	slots[slot] = null
	return p


func is_full() -> bool:
	return not slots.has(null)


func count() -> int:
	var n := 0
	for p in slots:
		if p != null:
			n += 1
	return n

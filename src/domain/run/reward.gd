class_name Reward extends RefCounted
## ③ Domain：受け取り待ちの報酬（戦闘報酬 / 宝箱。GameDesign §12.1・§12.2）。生成した時点で確定し、セーブされる。
## 1 行 = 1 つの RewardItem。受け取った行は taken になる。

var items: Array[RewardItem] = []


func add(item: RewardItem) -> void:
	items.append(item)


func item(index: int) -> RewardItem:
	if index < 0 or index >= items.size():
		return null
	return items[index]


func all_taken() -> bool:
	for i in items:
		if not i.taken:
			return false
	return true

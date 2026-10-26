class_name AutoChooser extends RefCounted
## ③ Domain：人間が操作していないとき（自動テスト / ボット / 敵のターン）のカード選択。決して詰まらない。
## card_effect ストリームでランダムに、選べる最大の枚数を選ぶ。


func choose(choice: CardChoice, rng: RngStreams) -> Array[Card]:
	var pool := choice.candidates.duplicate()
	rng.shuffle(&"card_effect", pool)
	var n := mini(choice.max_count, pool.size())
	var picked: Array[Card] = []
	for i in n:
		picked.append(pool[i])
	return picked

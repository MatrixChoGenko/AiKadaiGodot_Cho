class_name MapGraph extends RefCounted
## ③ Domain：1 アクトのマップ（GameDesign §4）。nodes[i].id == i。ボスは最後のノード。
## セーブにはシードではなくマップ全体を保存する（コンテンツが変わっても同じマップを再現するため。Architecture §12.2）。

## ボス以外の行数（ボスの行 = rows）。
var rows: int = 0
var columns: int = 0
var nodes: Array[MapNode] = []
var boss_id: int = -1


func node(id: int) -> MapNode:
	if id < 0 or id >= nodes.size():
		return null
	return nodes[id]


func boss() -> MapNode:
	return node(boss_id)


## 0 行目のノード（ランの開始時 / アクトの開始時に選べる）。
func start_nodes() -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in nodes:
		if n.row == 0:
			result.append(n)
	return result


## 現在地 from_id（-1 = まだどこにもいない）から次に選べるノード。
func choices_from(from_id: int) -> Array[MapNode]:
	if from_id < 0:
		return start_nodes()
	var result: Array[MapNode] = []
	var from := node(from_id)
	if from != null:
		for id in from.next:
			result.append(node(id))
	return result


## from_id のノードの親（前の行でつながっているノード）。
func parents_of(id: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in nodes:
		if n.next.has(id):
			result.append(n)
	return result


## from_id から（自分を含めて）たどり着けるノードの id。昇順。
func reachable_from(from_id: int) -> PackedInt32Array:
	var seen: Dictionary[int, bool] = {from_id: true}
	var stack: Array[int] = [from_id]
	while not stack.is_empty():
		var n := node(stack.pop_back())
		for id in n.next:
			if not seen.has(id):
				seen[id] = true
				stack.append(id)
	var ids := PackedInt32Array(seen.keys())
	ids.sort()
	return ids


func count_of(type: MapNode.Type) -> int:
	var n := 0
	for m in nodes:
		if m.type == type:
			n += 1
	return n

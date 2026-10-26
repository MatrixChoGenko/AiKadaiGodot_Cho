class_name MapNode extends RefCounted
## ③ Domain：マップのノード 1 つ（GameDesign §4）。内容（エンカウント / イベント）は生成時に割り当てて固定する。

## 値はセーブに使うので、既存の値の順序を変えない（追加は末尾へ）。
enum Type { BATTLE, ELITE, BOSS, EVENT, SHOP, REST, TREASURE }

var id: int
var row: int
var col: int
var type: Type = Type.BATTLE
## 次の行のつながっているノードの id（昇順）。
var next: PackedInt32Array = PackedInt32Array()
## 戦闘系ノードのエンカウント id。
var encounter: StringName = &""
## イベントノードのイベント id。
var event: StringName = &""


func _init(p_id: int = 0, p_row: int = 0, p_col: int = 0) -> void:
	id = p_id
	row = p_row
	col = p_col


func is_combat() -> bool:
	return type in [Type.BATTLE, Type.ELITE, Type.BOSS]


func _to_string() -> String:
	return "%s#%d(r%d c%d)" % [Type.keys()[type], id, row, col]

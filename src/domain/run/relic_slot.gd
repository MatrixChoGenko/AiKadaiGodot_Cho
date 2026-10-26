class_name RelicSlot extends BehaviorHost
## ③ Domain：所持しているレリック 1 つ（RelicData + カウンタ）。ラン中ずっと存在し、カウンタはセーブ対象。

var data: RelicData


func _init(relic: RelicData) -> void:
	data = relic


func behaviors() -> Array[CombatBehavior]:
	return data.behaviors


func id() -> StringName:
	return data.id


func is_relic() -> bool:
	return true

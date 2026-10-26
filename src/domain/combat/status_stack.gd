class_name StatusStack extends BehaviorHost
## ③ Domain：ユニットに付いた 1 種類のステータス（StatusData + スタック数）。

var data: StatusData
## 敵のターン中に付与された。そのラウンド終了時の減衰を受けない（GameDesign 付録 C の C2）。
var fresh: bool = false


func _init(status: StatusData, holder: Combatant, amount: int) -> void:
	data = status
	owner = holder
	stacks = amount


func behaviors() -> Array[CombatBehavior]:
	return data.behaviors


func id() -> StringName:
	return data.id

class_name DeathAction extends CombatAction
## ③ Domain：ユニットの死亡処理（push_bottom で積まれるので再帰しない）。死亡を確定させ、勝敗を判定する。

var unit: Combatant


func _init(p_unit: Combatant) -> void:
	unit = p_unit


func execute(combat: Combat) -> ActionQueue.Step:
	combat.finalize_death(unit)
	return ActionQueue.Step.DONE

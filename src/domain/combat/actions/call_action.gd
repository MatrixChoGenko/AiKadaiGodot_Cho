class_name CallAction extends CombatAction
## ③ Domain：任意の処理を包む（ターンの手順、プレイ終了後の後処理など）。

var callable: Callable


func _init(p_callable: Callable) -> void:
	callable = p_callable


func execute(_combat: Combat) -> ActionQueue.Step:
	callable.call()
	return ActionQueue.Step.DONE

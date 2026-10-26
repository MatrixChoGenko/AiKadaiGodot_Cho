class_name FlatDamageBonus extends CombatBehavior
## 与える攻撃ダメージ + スタック × per_stack（筋力）。OUTGOING_DAMAGE / ADD。

@export var per_stack: int = 1


func hooks() -> int:
	return Hook.OUTGOING_DAMAGE


func modify(_hook: Hook, host: BehaviorHost, _combat: Combat, calc: RefCounted) -> void:
	var d := calc as DamageCalc
	if d.source == host.owner and d.is_attack():
		d.amount += host.stacks * per_stack

class_name CheatDeath extends CombatBehavior
## 致死ダメージを受けたとき HP 1 で踏みとどまり、heal 回復してスタック −1（起死回生）。LETHAL。

@export var heal: int = 10


func hooks() -> int:
	return Hook.LETHAL


func modify(_hook: Hook, host: BehaviorHost, combat: Combat, calc: RefCounted) -> void:
	var d := calc as DamageCalc
	if d.target != host.owner or d.lethal_prevented or d.preview:
		return
	d.lethal_prevented = true
	d.revive_heal = heal
	combat.notify_triggered(host)
	combat.reduce_stacks(host as StatusStack, 1)

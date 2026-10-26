class_name KeepBlock extends CombatBehavior
## ターン開始時にブロックが消えなくなる（バリケード）。BLOCK_CLEAR。


func hooks() -> int:
	return Hook.BLOCK_CLEAR


func modify(_hook: Hook, host: BehaviorHost, _combat: Combat, calc: RefCounted) -> void:
	var c := calc as HookCalc
	if c.target == host.owner:
		c.cancelled = true

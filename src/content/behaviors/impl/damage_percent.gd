class_name DamagePercent extends CombatBehavior
## 攻撃ダメージを percent% 増減する（弱体 -25 / 脆弱 +50）。MULTIPLY。乗算後は 0 方向に切り捨て。

enum Direction { OUTGOING, INCOMING }

@export var direction: Direction = Direction.OUTGOING
@export_range(-100, 1000) var percent: int = 0


func hooks() -> int:
	return Hook.OUTGOING_DAMAGE if direction == Direction.OUTGOING else Hook.INCOMING_DAMAGE


func priority() -> int:
	return Priority.MULTIPLY


func modify(_hook: Hook, host: BehaviorHost, _combat: Combat, calc: RefCounted) -> void:
	var d := calc as DamageCalc
	if not d.is_attack():
		return
	var unit := d.source if direction == Direction.OUTGOING else d.target
	if unit == host.owner:
		d.amount = d.amount * (100 + percent) / 100

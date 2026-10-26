class_name TurnResources extends CombatBehavior
## ターンごとのエネルギー / ドローを補正する（黒い星、賢者の石、提灯、準備袋）。TURN_ENERGY / TURN_DRAW。
## 補正値は RunState に書き戻さない（複利にならない）。

@export var energy: int = 0
@export var draw: int = 0
@export var first_turn_only: bool = false


func hooks() -> int:
	return Hook.TURN_ENERGY | Hook.TURN_DRAW


func modify(hook: Hook, host: BehaviorHost, combat: Combat, calc: RefCounted) -> void:
	if first_turn_only and combat.turn.number != 1:
		return
	var c := calc as HookCalc
	var bonus := energy if hook == Hook.TURN_ENERGY else draw
	if bonus == 0:
		return
	c.amount += bonus
	if not c.preview:
		combat.notify_triggered(host)

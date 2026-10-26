class_name Retaliate extends CombatBehavior
## 攻撃（ATTACK）ダメージを受けたとき、攻撃者にスタック × per_stack の THORNS ダメージを返す（トゲ）。DAMAGED。
## ブロックで防いでも反撃する。反撃は今の一連の処理の後に予約する（再帰しない）。

@export var per_stack: int = 1


func hooks() -> int:
	return Hook.DAMAGED


func on_event(_hook: Hook, host: BehaviorHost, combat: Combat, payload: Variant) -> void:
	var d := payload as DamageCalc
	if d.target != host.owner or not d.is_attack() or d.source == null or d.source == host.owner:
		return
	combat.notify_triggered(host)
	combat.schedule_damage(host.owner, d.source, host.stacks * per_stack, DamageEffect.Kind.THORNS)

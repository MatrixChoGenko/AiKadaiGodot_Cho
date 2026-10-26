class_name HasStatusCondition extends Condition
## 自分 / 対象が特定のステータスを持つ（スタック 1 以上）。

@export var on: ValueSource.On = ValueSource.On.SELF
@export var status: StatusData


func _test(ctx: EffectContext, subject: Combatant) -> bool:
	var u := Condition.unit_of(ctx, on, subject)
	return u != null and u.stacks_of(status) > 0

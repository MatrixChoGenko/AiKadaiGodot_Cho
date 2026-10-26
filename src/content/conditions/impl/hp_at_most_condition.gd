class_name HpAtMostCondition extends Condition
## 自分 / 対象の HP が value 以下。

@export var on: ValueSource.On = ValueSource.On.SELF
@export var value: int = 1


func _test(ctx: EffectContext, subject: Combatant) -> bool:
	var u := Condition.unit_of(ctx, on, subject)
	return u != null and u.hp <= value

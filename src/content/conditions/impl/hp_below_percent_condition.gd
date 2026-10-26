class_name HpBelowPercentCondition extends Condition
## 自分 / 対象の HP が最大 HP の percent% 未満。

@export var on: ValueSource.On = ValueSource.On.SELF
@export_range(1, 100) var percent: int = 50


func _test(ctx: EffectContext, subject: Combatant) -> bool:
	var u := Condition.unit_of(ctx, on, subject)
	return u != null and u.hp * 100 < u.max_hp * percent

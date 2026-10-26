@abstract class_name Condition extends Resource
## ② Content：戦闘中の条件（Architecture §6.3。Specification パターン）。ステートレス。
## subject は TargetRule.require から呼ばれたときの候補のユニット（TARGET はその候補を指す）。

@export var negate: bool = false


func test(ctx: EffectContext, subject: Combatant = null) -> bool:
	return _test(ctx, subject) != negate


@abstract func _test(ctx: EffectContext, subject: Combatant) -> bool


static func unit_of(ctx: EffectContext, on: ValueSource.On, subject: Combatant) -> Combatant:
	if on == ValueSource.On.TARGET and subject != null:
		return subject
	return ValueSource.unit_of(ctx, on)

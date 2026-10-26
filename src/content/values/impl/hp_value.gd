class_name HpValue extends ValueSource
## 自分 / 対象の現在の HP。

@export var on: ValueSource.On = ValueSource.On.SELF


func _raw(ctx: EffectContext) -> int:
	var u := ValueSource.unit_of(ctx, on)
	return u.hp if u != null else 0

class_name MissingHpValue extends ValueSource
## 自分 / 対象の失った HP（最大 HP − 現在の HP）。

@export var on: ValueSource.On = ValueSource.On.SELF


func _raw(ctx: EffectContext) -> int:
	var u := ValueSource.unit_of(ctx, on)
	return u.max_hp - u.hp if u != null else 0

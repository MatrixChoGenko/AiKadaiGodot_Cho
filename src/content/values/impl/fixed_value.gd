class_name FixedValue extends ValueSource
## 固定値。

@export var value: int = 0


func _raw(_ctx: EffectContext) -> int:
	return value

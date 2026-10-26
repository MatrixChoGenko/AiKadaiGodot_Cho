class_name StatusStacksValue extends ValueSource
## 自分 / 対象の特定ステータスのスタック数。

@export var status: StatusData
@export var on: ValueSource.On = ValueSource.On.SELF


func _raw(ctx: EffectContext) -> int:
	var u := ValueSource.unit_of(ctx, on)
	return u.stacks_of(status) if u != null else 0

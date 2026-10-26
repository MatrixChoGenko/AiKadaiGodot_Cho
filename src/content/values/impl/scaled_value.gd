class_name ScaledValue extends ValueSource
## base + per × unit。ほとんどの動的な値はこれの組み合わせ（GameDesign §7.3「基本値 + 単位数 × 単位あたり」）。

@export var base: int = 0
@export var per: int = 1
@export var unit: ValueSource


func _raw(ctx: EffectContext) -> int:
	return base + per * (unit.evaluate(ctx) if unit != null else 0)

@abstract class_name RunCondition extends Resource
## ② Content：ラン中の条件（イベントの選択肢の可否など。GameDesign §7.5）。ステートレス。

@export var negate: bool = false


func test(ctx: RunEffectContext) -> bool:
	return _test(ctx) != negate


@abstract func _test(ctx: RunEffectContext) -> bool

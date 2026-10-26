class_name HasRelicRunCondition extends RunCondition
## 特定のレリックを持っている。

@export var relic: RelicData


func _test(ctx: RunEffectContext) -> bool:
	return ctx.state.has_relic(relic)

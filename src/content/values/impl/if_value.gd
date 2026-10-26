class_name IfValue extends ValueSource
## 条件で値を切り替える（「対象の HP が 50% 未満なら代わりに 20」などの 1 ヒットのカード用）。
## プレビューでも同じ条件で評価されるので、カード面の数字が条件に応じて変わる。

@export var when: Condition
@export var then: ValueSource
@export var otherwise: ValueSource


func _raw(ctx: EffectContext) -> int:
	var picked := then if when != null and when.test(ctx) else otherwise
	return picked.evaluate(ctx) if picked != null else 0

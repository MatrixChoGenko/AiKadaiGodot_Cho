class_name BranchRunEffect extends RunEffect
## 条件分岐。

@export var when: RunCondition
@export var then: Array[RunEffect] = []
@export var otherwise: Array[RunEffect] = []


func children() -> Array[RunEffect]:
	var all: Array[RunEffect] = []
	all.append_array(then)
	all.append_array(otherwise)
	return all


func apply(ctx: RunEffectContext) -> void:
	ctx.apply_all(then if ctx.test(when) else otherwise)

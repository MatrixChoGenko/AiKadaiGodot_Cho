class_name BranchEffect extends CardEffect
## コンビネータ：条件分岐（GameDesign §7.1 conditional）。条件は実行時に評価する。

@export var when: Condition
@export var then: Array[CardEffect] = []
@export var otherwise: Array[CardEffect] = []


func apply(ctx: EffectContext) -> void:
	ctx.combat.push_effects(then if when.test(ctx) else otherwise, ctx.child())


func preview(ctx: EffectContext, out: Preview) -> void:
	for e in (then if when.test(ctx) else otherwise):
		e.preview(ctx, out)


func children() -> Array[CardEffect]:
	var all: Array[CardEffect] = []
	all.append_array(then)
	all.append_array(otherwise)
	return all

class_name RandomChoiceEffect extends CardEffect
## コンビネータ：重み付きランダムで選択肢を選んで実行する（GameDesign §7.1 randomPick）。
## 乱数は card_effect ストリーム。インテントでは uncertain になる。

@export var options: Array[WeightedEffects] = []
@export_range(1, 10) var picks: int = 1
@export var allow_repeat: bool = false


func apply(ctx: EffectContext) -> void:
	var pool := options.duplicate()
	var actions: Array[CombatAction] = []
	for i in picks:
		if pool.is_empty():
			break
		var weights := PackedInt32Array()
		for o in pool:
			weights.append(o.weight)
		var index := ctx.combat.rng.weighted(&"card_effect", weights)
		if index < 0:
			break
		actions.append_array(ctx.combat.effect_actions(pool[index].effects, ctx.child()))
		if not allow_repeat:
			pool.remove_at(index)
	ctx.combat.queue.push_top_many(actions)


func preview(_ctx: EffectContext, out: Preview) -> void:
	out.uncertain = true


func children() -> Array[CardEffect]:
	var all: Array[CardEffect] = []
	for option in options:
		all.append_array(option.effects)
	return all

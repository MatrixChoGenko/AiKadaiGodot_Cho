class_name RepeatEffect extends CardEffect
## コンビネータ：子効果を N 回繰り返す（GameDesign §7.1 repeat）。回数の中では RepeatIndexValue が使える。
## 回数は実行を始めた時点で 1 回だけ評価する。

## プレビューで辿る回数の上限（インテントのヒット数などの集計用）。
const PREVIEW_LIMIT: int = 20

@export var times: ValueSource
@export var effects: Array[CardEffect] = []


func apply(ctx: EffectContext) -> void:
	var actions: Array[CombatAction] = []
	for i in maxi(times.evaluate(ctx), 0):
		var c := ctx.child()
		c.repeat_index = i
		actions.append_array(ctx.combat.effect_actions(effects, c))
	ctx.combat.queue.push_top_many(actions)


func preview(ctx: EffectContext, out: Preview) -> void:
	var n := clampi(times.evaluate(ctx), 1, PREVIEW_LIMIT)
	for i in n:
		for e in effects:
			e.preview(ctx, out)


func children() -> Array[CardEffect]:
	return effects

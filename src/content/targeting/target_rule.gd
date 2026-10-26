@abstract class_name TargetRule extends Resource
## ② Content：対象ルール（Architecture §6.4）。「誰に？」に答える。ステートレス。
## 「敵」「味方」は発動者から見た相対的な意味（敵の行動では、敵 = プレイヤー）。

## 発動者自身を除外する。
@export var exclude_self: bool = false
## プレイヤーが選んだ対象を除外する（「他のすべての敵」用）。
@export var exclude_chosen: bool = false
## この条件を満たすユニットだけに絞る。null = 絞らない。
@export var require: Condition


func resolve(ctx: EffectContext) -> Array[Combatant]:
	if ctx.combat == null:
		return []
	return _resolve(ctx)


## 候補を返す。候補は filter() を通してから選ぶ（ランダムなど）。
@abstract func _resolve(ctx: EffectContext) -> Array[Combatant]


## 共通のフィルタ（生存・除外・条件）を適用する。
func filter(ctx: EffectContext, units: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for u in units:
		if u == null or not u.is_alive():
			continue
		if exclude_self and u == ctx.source:
			continue
		if exclude_chosen and u == ctx.chosen:
			continue
		if require != null and not require.test(ctx, u):
			continue
		result.append(u)
	return result

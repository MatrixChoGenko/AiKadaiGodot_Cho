class_name RandomEnemiesTarget extends TargetRule
## ランダムな敵 count 体（card_effect 乱数ストリーム）。プレビューでは乱数を使わず先頭から取る。

@export_range(1, 10) var count: int = 1
@export var allow_repeat: bool = false


func _resolve(ctx: EffectContext) -> Array[Combatant]:
	var pool := filter(ctx, ctx.combat.opponents_of(ctx.source))
	var picked: Array[Combatant] = []
	if pool.is_empty():
		return picked
	if ctx.preview:
		for i in mini(count, pool.size()):
			picked.append(pool[i])
		return picked
	if allow_repeat:
		for i in count:
			picked.append(ctx.combat.rng.pick(&"card_effect", pool))
		return picked
	ctx.combat.rng.shuffle(&"card_effect", pool)
	for i in mini(count, pool.size()):
		picked.append(pool[i])
	return picked

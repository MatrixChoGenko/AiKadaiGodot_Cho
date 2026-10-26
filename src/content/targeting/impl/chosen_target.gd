class_name ChosenTarget extends TargetRule
## プレイヤーが選んだ対象。敵の行動ではプレイヤー。これを使うカードは aim = ENEMY にする。


func _resolve(ctx: EffectContext) -> Array[Combatant]:
	var units: Array[Combatant] = []
	if ctx.chosen != null:
		units.append(ctx.chosen)
	return filter(ctx, units)

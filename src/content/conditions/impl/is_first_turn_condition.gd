class_name IsFirstTurnCondition extends Condition
## 戦闘の第 1 ターン。


func _test(ctx: EffectContext, _subject: Combatant) -> bool:
	return ctx.combat != null and ctx.combat.turn.number == 1

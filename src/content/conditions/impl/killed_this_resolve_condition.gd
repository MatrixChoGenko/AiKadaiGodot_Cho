class_name KilledThisResolveCondition extends Condition
## 今回の解決で敵を 1 体以上倒した。


func _test(ctx: EffectContext, _subject: Combatant) -> bool:
	return ctx.stats.kills > 0

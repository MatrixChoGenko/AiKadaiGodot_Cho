class_name AliveEnemiesValue extends ValueSource
## 生存している敵の数（発動者から見た敵）。


func _raw(ctx: EffectContext) -> int:
	return ctx.combat.opponents_of(ctx.source).size() if ctx.combat != null else 0

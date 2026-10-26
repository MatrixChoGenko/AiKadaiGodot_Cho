class_name ResolveStatValue extends ValueSource
## 今回の解決（カード 1 枚のプレイ全体）の統計。

enum Stat { DAMAGE_DEALT, LAST_DAMAGE, CARDS_AFFECTED, CONSUMED_STACKS, KILLS }

@export var stat: Stat = Stat.DAMAGE_DEALT


func _raw(ctx: EffectContext) -> int:
	return ctx.stats.get_stat(stat)

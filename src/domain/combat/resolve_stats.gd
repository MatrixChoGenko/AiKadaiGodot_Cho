class_name ResolveStats extends RefCounted
## ③ Domain：カード 1 枚（またはポーション / 敵の行動 1 つ）の解決全体の統計。ResolveStatValue が読む。

var damage_dealt: int = 0
var last_damage: int = 0
var cards_affected: int = 0
var consumed_stacks: int = 0
var kills: int = 0


func get_stat(stat: ResolveStatValue.Stat) -> int:
	match stat:
		ResolveStatValue.Stat.DAMAGE_DEALT:
			return damage_dealt
		ResolveStatValue.Stat.LAST_DAMAGE:
			return last_damage
		ResolveStatValue.Stat.CARDS_AFFECTED:
			return cards_affected
		ResolveStatValue.Stat.CONSUMED_STACKS:
			return consumed_stacks
		_:
			return kills

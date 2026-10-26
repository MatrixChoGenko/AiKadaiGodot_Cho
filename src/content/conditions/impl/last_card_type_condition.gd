class_name LastCardTypeCondition extends Condition
## このターンに直前にプレイしたカード（今プレイ中のカードの 1 つ前）の種類が type_filter に含まれる。
## このターンにまだ何もプレイしていなければ false。

@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = CardData.TYPE_BIT_ATTACK


func _test(ctx: EffectContext, _subject: Combatant) -> bool:
	if ctx.combat == null or ctx.combat.turn.last_type < 0:
		return false
	return (1 << ctx.combat.turn.last_type) & type_filter != 0

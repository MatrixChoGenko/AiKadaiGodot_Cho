class_name HandHasTypeCondition extends Condition
## 手札に type_filter の種類のカードがある（このカード自身は除く）。

@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = 0


func _test(ctx: EffectContext, _subject: Combatant) -> bool:
	return ctx.combat != null and ctx.combat.piles.count_in_hand(type_filter, ctx.card) > 0

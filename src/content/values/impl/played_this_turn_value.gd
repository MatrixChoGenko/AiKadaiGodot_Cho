class_name PlayedThisTurnValue extends ValueSource
## このターンにプレイしたカードの枚数（種類で絞れる）。プレイ中のカード自身を含む（GameDesign 付録 C の C15）。
## プレビュー中（カードがまだ手札にある）は、そのカード自身を 1 枚として足す。

## CardData.TYPE_BIT_* の和。0 = すべて。
@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = 0


func _raw(ctx: EffectContext) -> int:
	if ctx.combat == null:
		return 0
	var n := ctx.combat.turn.played_count(type_filter)
	if ctx.preview and ctx.card != null and ctx.combat.piles.hand.has(ctx.card) and ctx.card.matches(type_filter):
		n += 1
	return n

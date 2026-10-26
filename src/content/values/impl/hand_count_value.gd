class_name HandCountValue extends ValueSource
## 手札の枚数（種類で絞れる）。プレイ中のカード自身は数えない（プレビュー中も除く）。

## CardData.TYPE_BIT_* の和。0 = すべて。
@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = 0


func _raw(ctx: EffectContext) -> int:
	return ctx.combat.piles.count_in_hand(type_filter, ctx.card) if ctx.combat != null else 0

class_name PileSizeValue extends ValueSource
## 山の枚数（山札 / 手札 / 捨て札 / 廃棄札）。

@export var pile: Pile.Id = Pile.Id.DISCARD


func _raw(ctx: EffectContext) -> int:
	return ctx.combat.piles.pile(pile).size() if ctx.combat != null else 0

class_name DiscardEffect extends CardEffect
## 手札を捨てる（GameDesign §7.1 discard）。プレイヤーが選ぶ場合は ChooseCardsEffect を使う。
## 捨てた枚数は解決の統計（CARDS_AFFECTED）に加算される。

enum Mode { RANDOM, ALL }

@export var mode: Mode = Mode.ALL
## RANDOM のときの枚数。
@export var count: ValueSource
## 対象にするカードの種類（CardData.TYPE_BIT_*）。0 = すべて。
@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = 0


func apply(ctx: EffectContext) -> void:
	var cards := pick_from_hand(ctx, mode == Mode.ALL, count, type_filter)
	for c in cards:
		ctx.combat.discard_from_hand(c)
	ctx.stats.cards_affected += cards.size()


## 手札から（このカード自身を除いて）すべて、またはランダムに count 枚を選ぶ。ExhaustEffect と共用。
static func pick_from_hand(ctx: EffectContext, all: bool, how_many: ValueSource, filter: int) -> Array[Card]:
	var pool: Array[Card] = []
	for c in ctx.combat.piles.hand:
		if c != ctx.card and c.matches(filter):
			pool.append(c)
	if all:
		return pool
	ctx.combat.rng.shuffle(&"card_effect", pool)
	var n := mini(how_many.evaluate(ctx) if how_many != null else 1, pool.size())
	return pool.slice(0, n)

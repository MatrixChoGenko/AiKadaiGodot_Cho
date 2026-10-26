class_name ExhaustEffect extends CardEffect
## 手札を廃棄する（GameDesign §7.1 exhaust）。プレイヤーが選ぶ場合は ChooseCardsEffect を使う。
## 自分自身の廃棄はキーワード「廃棄」で表す。廃棄した枚数は解決の統計（CARDS_AFFECTED）に加算される。

enum Mode { RANDOM, ALL }

@export var mode: Mode = Mode.ALL
## RANDOM のときの枚数。
@export var count: ValueSource
## 対象にするカードの種類（CardData.TYPE_BIT_*）。0 = すべて。
@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = 0


func apply(ctx: EffectContext) -> void:
	var cards := DiscardEffect.pick_from_hand(ctx, mode == Mode.ALL, count, type_filter)
	for c in cards:
		ctx.combat.exhaust_card(c)
	ctx.stats.cards_affected += cards.size()

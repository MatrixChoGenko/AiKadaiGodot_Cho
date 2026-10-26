class_name ChooseCardsEffect extends CardEffect
## カードを選んで処理する（GameDesign §7.1 selectCards / §5.9）。解決を一時停止する唯一の効果。
## 処理した枚数は解決の統計（CARDS_AFFECTED）に加算される。

enum Action { DISCARD, EXHAUST, RETAIN, DUPLICATE, TO_DRAW_TOP, TO_DRAW_BOTTOM, TO_HAND, TO_DISCARD }

@export var source: Pile.Id = Pile.Id.HAND
@export var action: Action = Action.DISCARD
## 選ぶ枚数（上限）。
@export_range(1, 10) var count: int = 1
## 上限より少なく選んでもよい（0 枚も可）。
@export var allow_fewer: bool = false
@export var cancellable: bool = false
## 候補にするカードの種類（CardData.TYPE_BIT_*）。0 = すべて。
@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = 0
@export var prompt: String


func apply(ctx: EffectContext) -> void:
	ctx.combat.request_choice(self, ctx)

class_name RedirectCardDestination extends CombatBehavior
## プレイした type_filter のカードの行き先を place に書き換える（リサイクラー：スキル → 山札にシャッフル）。CARD_DESTINATION。
## 捨て札へ行くカードだけが対象（廃棄されるカードは廃棄のまま）。

@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = CardData.TYPE_BIT_SKILL
@export var place: Pile.Place = Pile.Place.DRAW_RANDOM


func hooks() -> int:
	return Hook.CARD_DESTINATION


func modify(_hook: Hook, host: BehaviorHost, combat: Combat, calc: RefCounted) -> void:
	var c := calc as HookCalc
	if c.place == Pile.Place.DISCARD and c.card.matches(type_filter):
		c.place = place
		combat.notify_triggered(host)

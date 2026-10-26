class_name EveryNCardsHeal extends CombatBehavior
## type_filter のカードを n 枚プレイするごとに HP を heal 回復する（瞑想の数珠）。CARD_PLAYED。カウントは host.counter（戦闘をまたいで残る）。

@export_flags("Attack", "Skill", "Power", "Status", "Curse") var type_filter: int = CardData.TYPE_BIT_SKILL
@export_range(1, 20) var n: int = 3
@export var heal: int = 2


func hooks() -> int:
	return Hook.CARD_PLAYED


func on_event(_hook: Hook, host: BehaviorHost, combat: Combat, payload: Variant) -> void:
	if not (payload as Card).matches(type_filter):
		return
	host.counter += 1
	if host.counter >= n:
		host.counter = 0
		combat.notify_triggered(host)
		combat.heal(host.owner, heal)

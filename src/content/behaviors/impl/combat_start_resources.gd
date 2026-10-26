class_name CombatStartResources extends CombatBehavior
## 戦闘開始時にブロック / 回復を得る（錨、血の小瓶）。COMBAT_START。
## 第 1 ターン開始時はブロックが消えないので、ここで得たブロックは第 1 ターンに残る（GameDesign §5.2）。

@export var block: int = 0
@export var heal: int = 0


func hooks() -> int:
	return Hook.COMBAT_START


func on_event(_hook: Hook, host: BehaviorHost, combat: Combat, _payload: Variant) -> void:
	combat.notify_triggered(host)
	if block > 0:
		combat.gain_block(host.owner, block)
	if heal > 0:
		combat.heal(host.owner, heal)

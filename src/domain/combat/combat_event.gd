class_name CombatEvent extends RefCounted
## ③ Domain：戦闘で起きたことの記録（Architecture §7.9）。ルール層は書くだけで読まない。
## snapshot には表現に必要な「その時点の値」（被ダメージ後の HP など）を入れ、表現層がモデルを見返さずに済むようにする。

## TURN_ENDING = ターン終了を押した瞬間（後始末の前。表現層が敵のターンの合図を出す）、TURN_ENDED = 手札の後始末の後。
enum Kind { COMBAT_STARTED, TURN_STARTED, TURN_ENDING, TURN_ENDED, ENEMY_TURN_STARTED,
		CARD_DRAWN, CARD_PLAYED, CARD_DISCARDED, CARD_EXHAUSTED, CARD_CREATED, CARD_RETAINED, CARD_MOVED, CARD_UPDATED,
		PILE_SHUFFLED, CHOICE_REQUESTED, CHOICE_RESOLVED,
		DAMAGED, BLOCKED, HEALED, BLOCK_GAINED, BLOCK_CLEARED,
		STATUS_APPLIED, STATUS_REMOVED, STATUS_TRIGGERED,
		ENERGY_CHANGED, INTENT_CHANGED, POTION_USED, POTION_DISCARDED,
		RELIC_TRIGGERED, UNIT_DIED, PHASE_CHANGED, COMBAT_ENDED, READY_CHANGED }

## DAMAGED の flags。
const FLAG_LETHAL: int = 1
const FLAG_OVERKILL: int = 2
const FLAG_REVIVED: int = 4

var kind: Kind
var source_uid: int = -1
var target_uid: int = -1
var value: int = 0
var id: StringName
var flags: int = 0
var snapshot: Dictionary = {}


func _to_string() -> String:
	return "%s(src=%d tgt=%d v=%d id=%s f=%d)" % [Kind.keys()[kind], source_uid, target_uid, value, id, flags]

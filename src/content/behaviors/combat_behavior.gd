@abstract class_name CombatBehavior extends Resource
## ② Content：ステータス / レリックの持続ルール（Architecture §8.1）。
## ステートレス。スタック数・カウンタは host から読み、カウントが必要なら host.counter に書く。
## M1 ではデータだけ。hooks() / on_event() / modify() は M2 で各サブクラスに実装する。

enum Hook {
	TURN_START = 1 << 0, TURN_END = 1 << 1, COMBAT_START = 1 << 2, COMBAT_END = 1 << 3,
	CARD_PLAYED = 1 << 4, CARD_DRAWN = 1 << 5, CARD_DISCARDED = 1 << 6, CARD_RESOLVED = 1 << 7,
	OUTGOING_DAMAGE = 1 << 8, INCOMING_DAMAGE = 1 << 9, DAMAGED = 1 << 10, LETHAL = 1 << 11,
	BLOCK_GAIN = 1 << 12, BLOCK_CLEAR = 1 << 13, HEAL = 1 << 14, STATUS_APPLY = 1 << 15,
	STATUS_APPLIED = 1 << 16, DEATH = 1 << 17, CARD_COST = 1 << 18, CARD_DESTINATION = 1 << 19,
	PLAY_COUNT = 1 << 20, TURN_ENERGY = 1 << 21, TURN_DRAW = 1 << 22, ROUND_END = 1 << 23,
}
enum Priority { EARLY = -100, ADD = 0, MULTIPLY = 100, CLAMP = 200 }


## 購読する Hook のビット和。
func hooks() -> int:
	return 0


func priority() -> int:
	return Priority.ADD


## 通知型（戻り値なし）。
func on_event(_hook: Hook, _host: BehaviorHost, _combat: Combat, _payload: Variant) -> void:
	pass


## 補正型（calc オブジェクトを書き換える）。
func modify(_hook: Hook, _host: BehaviorHost, _combat: Combat, _calc: RefCounted) -> void:
	pass

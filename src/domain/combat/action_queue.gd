class_name ActionQueue extends RefCounted
## ③ Domain：戦闘の変化はすべてここに積まれる CombatAction を順に実行して起こす（Architecture §7.4、Command パターン）。
## push_top：子効果・コンビネータの展開（すぐ続けて実行）。push_bottom：トリガー（今の一連の処理の後で実行。再帰しない）。
## WAIT を返すアクションに当たると一時停止し、もう一度 run() すると続きから再開する。

enum Step { DONE, WAIT }

## 1 回の run() で実行するアクションの上限（無限ループ防止）。リリースビルドでも働くよう assert は使わない。
const STEP_LIMIT: int = 20000

var _items: Array[CombatAction] = []
var _running: bool = false
## 上限を超えて止まった。
var runaway: bool = false


func push_top(a: CombatAction) -> void:
	_items.push_front(a)


## 渡した順に実行されるように先頭へ積む。
func push_top_many(list: Array[CombatAction]) -> void:
	for i in range(list.size() - 1, -1, -1):
		_items.push_front(list[i])


func push_bottom(a: CombatAction) -> void:
	_items.push_back(a)


func is_empty() -> bool:
	return _items.is_empty()


func size() -> int:
	return _items.size()


func clear() -> void:
	_items.clear()


## 空になるか WAIT に当たるまで実行する。再入しても二重には走らない。
func run(combat: Combat) -> void:
	if _running:
		return
	_running = true
	var steps := 0
	while not _items.is_empty() and not combat.is_over():
		steps += 1
		if steps > STEP_LIMIT:
			runaway = true
			push_error("ActionQueue: step limit exceeded; aborting the combat")
			_items.clear()
			combat.abort()
			break
		var a: CombatAction = _items.pop_front()
		if a.execute(combat) == Step.WAIT:
			_items.push_front(a)
			break
	_running = false

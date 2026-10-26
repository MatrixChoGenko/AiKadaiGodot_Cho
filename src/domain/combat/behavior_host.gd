@abstract class_name BehaviorHost extends RefCounted
## ③ Domain：Behavior の持ち主（ステータスのスタック / レリック）。Architecture §8.1。
## Behavior 自身は状態を持たないので、スタック数とカウンタはここに置く。

## 持ち主のユニット（レリックならプレイヤー）。ユニット → ステータス → ユニットの循環参照を作らないよう弱参照で持つ。
var owner: Combatant:
	get:
		return _owner_ref.get_ref() as Combatant if _owner_ref != null else null
	set(value):
		_owner_ref = weakref(value) if value != null else null
## ステータスのスタック数。レリックでは常に 1。
var stacks: int = 1
## Behavior が自由に使うカウンタ（ペン先の「このターン使ったか」、瞑想の数珠の枚数など）。
var counter: int = 0

var _owner_ref: WeakRef


@abstract func behaviors() -> Array[CombatBehavior]


@abstract func id() -> StringName


func is_relic() -> bool:
	return false

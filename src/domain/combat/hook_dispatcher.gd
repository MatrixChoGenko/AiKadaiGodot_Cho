class_name HookDispatcher extends RefCounted
## ③ Domain：Behavior の収集・安定ソート・呼び出し（Architecture §8.2）。
## プル型：呼ばれるたびに、生存ユニットのステータス + プレイヤーのレリックから、その Hook を購読する Behavior を集める。
## 購読 / 解除の管理が無いので、ステータスが消えればその Behavior も自然に効かなくなる。

## Combat が自分を持っているので、循環参照にならないよう弱参照で持つ。
var _combat: Combat:
	get:
		return _combat_ref.get_ref() as Combat
var _combat_ref: WeakRef


func _init(combat: Combat) -> void:
	_combat_ref = weakref(combat)


## 通知型の Hook を呼ぶ。
func notify(hook: CombatBehavior.Hook, payload: Variant = null) -> void:
	for entry in collect(hook):
		var behavior: CombatBehavior = entry[0]
		var host: BehaviorHost = entry[1]
		# 先に呼ばれた Behavior がステータスを消したら、その host の Behavior はもう呼ばない。
		if not _host_alive(host):
			continue
		behavior.on_event(hook, host, _combat, payload)


## 補正型の Hook を呼ぶ（calc を書き換える）。
func modify(hook: CombatBehavior.Hook, calc: RefCounted) -> void:
	for entry in collect(hook):
		var behavior: CombatBehavior = entry[0]
		var host: BehaviorHost = entry[1]
		if not _host_alive(host):
			continue
		behavior.modify(hook, host, _combat, calc)


## 席ごとの Hook（カードのプレイ・コスト・行き先・ドロー、ターンのエネルギー / ドロー）。
## 協力プレイでは、いまの席（Combat.seat）のプレイヤーのステータスとレリックだけが反応する
## （ほかの人のカードで自分のペン先が反応しないように）。敵のステータスは誰のカードにも反応する。
const SEAT_HOOKS: int = CombatBehavior.Hook.CARD_PLAYED | CombatBehavior.Hook.CARD_DRAWN \
		| CombatBehavior.Hook.CARD_DISCARDED | CombatBehavior.Hook.CARD_RESOLVED | CombatBehavior.Hook.CARD_COST \
		| CombatBehavior.Hook.CARD_DESTINATION | CombatBehavior.Hook.PLAY_COUNT | CombatBehavior.Hook.TURN_ENERGY \
		| CombatBehavior.Hook.TURN_DRAW


## [behavior, host] の配列を priority で安定ソートして返す。
## 収集順：プレイヤーのステータス（席の順）→ 敵のステータス（左から）→ レリック（席の順、取得順）。
func collect(hook: CombatBehavior.Hook) -> Array[Array]:
	var c := _combat
	var entries: Array[Array] = []
	var seat_only := hook & SEAT_HOOKS != 0
	var seats: Array[PlayerSeat] = c.seats
	if seat_only:
		seats = [c.seat]
	var units: Array[Combatant] = []
	for s in seats:
		units.append(s.unit)
	units.append_array(c.enemies)
	for unit in units:
		if not unit.is_alive():
			continue
		for stack in unit.statuses.all():
			_add_entries(entries, stack, hook)
	for s in seats:
		for relic in s.relics:
			_add_entries(entries, relic, hook)
	_stable_sort(entries)
	return entries


func _add_entries(entries: Array[Array], host: BehaviorHost, hook: CombatBehavior.Hook) -> void:
	for behavior in host.behaviors():
		if behavior.hooks() & hook:
			entries.append([behavior, host])


func _host_alive(host: BehaviorHost) -> bool:
	if host.is_relic():
		return true
	var stack := host as StatusStack
	return stack.stacks > 0 and stack.owner.is_alive() and stack.owner.statuses.all().has(stack)


## 挿入ソート（安定）。Array.sort_custom は安定ではないので使わない（Architecture §21 ルール 14）。
static func _stable_sort(entries: Array[Array]) -> void:
	for i in range(1, entries.size()):
		var item: Array = entries[i]
		var p: int = (item[0] as CombatBehavior).priority()
		var j := i - 1
		while j >= 0 and (entries[j][0] as CombatBehavior).priority() > p:
			entries[j + 1] = entries[j]
			j -= 1
		entries[j + 1] = item

class_name PlayResult extends RefCounted
## ③ Domain：カード / ポーションを使えるか、使った結果。ok でなければ reason に理由。

const NOT_YOUR_TURN: StringName = &"NOT_YOUR_TURN"
const NOT_IN_HAND: StringName = &"NOT_IN_HAND"
const NOT_ENOUGH_ENERGY: StringName = &"NOT_ENOUGH_ENERGY"
const UNPLAYABLE: StringName = &"UNPLAYABLE"
const NEED_TARGET: StringName = &"NEED_TARGET"
const INVALID_TARGET: StringName = &"INVALID_TARGET"
const BLOCKED_BY_EFFECT: StringName = &"BLOCKED_BY_EFFECT"
const WAITING_FOR_CHOICE: StringName = &"WAITING_FOR_CHOICE"
const COMBAT_OVER: StringName = &"COMBAT_OVER"
const NO_POTION: StringName = &"NO_POTION"

var ok: bool = true
var reason: StringName


static func success() -> PlayResult:
	return PlayResult.new()


static func fail(why: StringName) -> PlayResult:
	var r := PlayResult.new()
	r.ok = false
	r.reason = why
	return r

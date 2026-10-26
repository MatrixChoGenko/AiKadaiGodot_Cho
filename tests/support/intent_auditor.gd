class_name IntentAuditor extends RefCounted
## テスト支援：不変条件「インテントの数字 == 実際に受けるダメージ」（GameDesign §1 デザインの柱 2）を検査する。
## 敵が行動を始めた瞬間（ENEMY_TURN_STARTED）のインテントと、その行動で実際に出たプレイヤーへの攻撃ダメージ
## （ブロックで防いだ分も含む）を比べる。食い違いは mismatches に記録する。

var mismatches: PackedStringArray = []
var checked_hits: int = 0

var _ctl: CombatController
var _actor: Combatant
var _expected: Intent
var _hits: int = 0
var _blocked: int = 0


func _init(ctl: CombatController) -> void:
	_ctl = ctl
	ctl.event_emitted.connect(_on_event)


func _on_event(e: CombatEvent) -> void:
	var combat := _ctl.combat
	match e.kind:
		CombatEvent.Kind.ENEMY_TURN_STARTED:
			_finish()
			_actor = _find(e.source_uid)
			_expected = combat.intent_of(_actor)
			_hits = 0
			_blocked = 0
		CombatEvent.Kind.TURN_STARTED, CombatEvent.Kind.COMBAT_ENDED:
			_finish()
		CombatEvent.Kind.BLOCKED:
			if _is_attack_on_player(e):
				_blocked = e.value
		CombatEvent.Kind.DAMAGED:
			if not _is_attack_on_player(e) or e.snapshot.get("kind", -1) != DamageEffect.Kind.ATTACK:
				return
			var dealt := e.value + _blocked
			_blocked = 0
			_hits += 1
			if e.flags & (CombatEvent.FLAG_LETHAL | CombatEvent.FLAG_REVIVED):
				return   # 致死では HP の減少が残り HP で頭打ちになるので比べない
			checked_hits += 1
			if not _expected.uncertain and dealt != _expected.damage:
				mismatches.append("%s %s: intent %d but dealt %d" % [_actor.name, _expected.move_id, _expected.damage, dealt])


func _finish() -> void:
	if _actor == null or _expected == null:
		return
	# 途中で倒れた / プレイヤーが倒れた / 起死回生などでヒット数が減るのは許す。
	if not _expected.uncertain and _actor.is_alive() and _ctl.combat.player.is_alive() and _hits > _expected.hits:
		mismatches.append("%s %s: intent %d hits but hit %d times" % [_actor.name, _expected.move_id, _expected.hits, _hits])
	_actor = null
	_expected = null


func _is_attack_on_player(e: CombatEvent) -> bool:
	return _actor != null and e.source_uid == _actor.uid and e.target_uid == _ctl.combat.player.uid


func _find(uid: int) -> Combatant:
	for u in _ctl.combat.enemies:
		if u.uid == uid:
			return u
	return null

class_name CoopCommands extends RefCounted
## ④ Flow：協力プレイのコマンド（GameDesign §21 / Architecture §23）。
## ネットワークで送るのはこの形の Dictionary だけ：{seq, seat, op, args}。カード・ユニットはオブジェクトではなく uid で指す。
## どの PC でも同じ順番で apply() すれば同じ状態になる（ロックステップ）。digest() はずれの検出用の要約。
## ネットワークとは無関係な純粋な処理なので、テストで 2 つの RunController に同じ列を流して一致を確かめられる。

const VOTE: StringName = &"vote"
const LEAVE: StringName = &"leave"
const CANCEL_LEAVE: StringName = &"cancel_leave"
const ADVANCE_ACT: StringName = &"advance_act"
const ACK_COMBAT: StringName = &"ack_combat"
const TAKE_REWARD: StringName = &"take_reward"
const DISCARD_POTION: StringName = &"discard_potion"
const BUY: StringName = &"buy"
const BUY_REMOVAL: StringName = &"buy_removal"
const BUY_UPGRADE: StringName = &"buy_upgrade"
const EVENT_OPTION: StringName = &"event_option"
const RESOLVE_REQUEST: StringName = &"resolve_request"
const REST_HEAL: StringName = &"rest_heal"
const REST_UPGRADE: StringName = &"rest_upgrade"
const PLAY: StringName = &"play"
const USE_POTION: StringName = &"use_potion"
const COMBAT_DISCARD_POTION: StringName = &"combat_discard_potion"
const SUBMIT_CHOICE: StringName = &"submit_choice"
const END_TURN: StringName = &"end_turn"
const CANCEL_READY: StringName = &"cancel_ready"
## ホストだけが送れる：ランを諦める（全員がメニューへ）。
const ABANDON: StringName = &"abandon"


static func make(seat: int, op: StringName, args: Dictionary = {}) -> Dictionary:
	return {seq = 0, seat = seat, op = String(op), args = args}


## コマンドを 1 つ実行する。受け付けられなければ false（状態は変わらない）。
static func apply(run: RunController, cmd: Dictionary) -> bool:
	if run == null or run.state == null:
		return false
	var seat: int = int(cmd.get("seat", -1))
	if seat < 0 or seat >= run.state.players.size():
		return false
	var a: Dictionary = cmd.get("args", {})
	var op := StringName(cmd.get("op", ""))
	match op:
		VOTE:
			return run.vote(int(a.get("node", -1)), seat)
		LEAVE:
			return run.leave_node(seat)
		CANCEL_LEAVE:
			return run.cancel_leave(seat)
		ADVANCE_ACT:
			return run.advance_act(seat)
		ACK_COMBAT:
			return run.acknowledge_combat_end()
		TAKE_REWARD:
			return run.take_reward(int(a.get("item", -1)), int(a.get("card", -1)), seat)
		DISCARD_POTION:
			return run.discard_potion(int(a.get("slot", -1)), seat)
		BUY:
			return run.buy(int(a.get("item", -1)), seat)
		BUY_REMOVAL:
			var card := run.player(seat).deck.find_uid(int(a.get("card", -1)))
			return card != null and run.buy_removal(card, seat)
		BUY_UPGRADE:
			var card := run.player(seat).deck.find_uid(int(a.get("card", -1)))
			return card != null and run.buy_upgrade(card, seat)
		EVENT_OPTION:
			return run.choose_event_option(int(a.get("option", -1)), seat) != null
		RESOLVE_REQUEST:
			return run.resolve_request(PackedInt32Array(a.get("indices", [])), seat)
		REST_HEAL:
			return run.rest_heal(seat)
		REST_UPGRADE:
			var card := run.player(seat).deck.find_uid(int(a.get("card", -1)))
			return card != null and run.rest_upgrade(card, seat)
		ABANDON:
			if seat != 0:
				return false
			run.abandon()
			return true
	return apply_combat(run.combat, seat, op, a)


## 戦闘のコマンド（ランの外の戦闘 = サンドボックスでも使う）。
static func apply_combat(ctl: CombatController, seat: int, op: StringName, a: Dictionary) -> bool:
	if ctl == null:
		return false
	var c := ctl.combat
	if seat >= c.seats.size():
		return false
	match op:
		PLAY:
			var card := _hand_card(c.seats[seat], int(a.get("card", -1)))
			if card == null:
				return false
			return ctl.play_card(card, unit_of(c, int(a.get("target", -1))), seat).ok
		USE_POTION:
			return ctl.use_potion(int(a.get("slot", -1)), unit_of(c, int(a.get("target", -1))), seat).ok
		COMBAT_DISCARD_POTION:
			return ctl.discard_potion(int(a.get("slot", -1)), seat)
		SUBMIT_CHOICE:
			var choice := ctl.pending_choice()
			if choice == null:
				return false
			var cards: Array[Card] = []
			for uid: Variant in a.get("cards", []):
				var found: Card = null
				for cand in choice.candidates:
					if cand.uid == int(uid):
						found = cand
				if found == null:
					return false
				cards.append(found)
			return ctl.submit_choice(cards, seat)
		END_TURN:
			return ctl.end_turn(seat)
		CANCEL_READY:
			return ctl.cancel_ready(seat)
	return false


static func _hand_card(s: PlayerSeat, uid: int) -> Card:
	for card in s.piles.hand:
		if card.uid == uid:
			return card
	return null


## uid のユニット（プレイヤー / 敵）。-1 や見つからなければ null。
static func unit_of(c: Combat, uid: int) -> Combatant:
	if uid < 0:
		return null
	for s in c.seats:
		if s.unit.uid == uid:
			return s.unit
	for e in c.enemies:
		if e.uid == uid:
			return e
	return null


## 状態の要約（ずれの検出用）。ラン全体（セーブと同じ形）と、戦闘中なら全ユニットの HP / ブロック、山の枚数、エネルギー、乱数。
static func digest(run: RunController) -> int:
	if run == null or run.state == null:
		return 0
	var parts: Array = [RunSerializer.to_dict(run.state), RunPhase.Id.keys()[run.state.phase]]
	for p in run.state.players:
		parts.append([p.done, p.vote, p.event_choice, p.rest_used, p.pending_requests.size()])
	if run.combat != null:
		var c := run.combat.combat
		parts.append([c.version, c.outcome, c.rng.save()])
		for s in c.seats:
			parts.append([s.unit.hp, s.unit.block, s.turn.energy, s.ready, s.piles.hand.size(), s.piles.draw.size(),
					s.piles.discard.size(), s.piles.exhaust.size()])
		for e in c.enemies:
			parts.append([e.hp, e.block, e.mind.current_move.id if e.mind.current_move != null else &""])
	return hash(JSON.stringify(parts))

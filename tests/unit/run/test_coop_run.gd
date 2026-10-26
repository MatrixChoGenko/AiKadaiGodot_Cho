extends GutTest
## 協力プレイのラン進行（GameDesign §21）：投票・各自の報酬 / ショップ / 休憩 / イベント・全員の「進む」・復活・セーブ。

const F = preload("res://tests/support/builders/run_fixtures.gd")

var _lib: ContentLibrary


func before_all() -> void:
	_lib = OfficialSetup.library()


func _coop(n: int = 2, seed_value: int = 5) -> RunController:
	var run := RunController.new(_lib)
	var names := PackedStringArray()
	for i in n:
		names.append("P%d" % i)
	run.start_new(seed_value, true, names)
	return run


func _vote_all(run: RunController, node_id: int) -> void:
	for p in run.state.players:
		run.vote(node_id, p.index)


func test_each_player_gets_their_own_starting_kit() -> void:
	var run := _coop(3)
	assert_eq(run.state.players.size(), 3)
	var uids: Dictionary = {}
	for p in run.state.players:
		assert_eq(p.hp, 80)
		assert_eq(p.gold, 99)
		assert_eq(p.deck.size(), 10)
		assert_eq(p.name, "P%d" % p.index)
		for c in p.deck.cards:
			assert_false(uids.has(c.uid), "カードの uid は全員で重ならない")
			uids[c.uid] = true


func test_map_waits_for_every_vote_and_majority_wins() -> void:
	var run := _coop(3)
	var options := run.choices()
	if options.size() < 2:
		pass_test("この seed は選択肢が 1 つ")
		return
	assert_true(run.vote(options[0].id, 0))
	assert_true(run.vote(options[1].id, 1))
	assert_eq(run.state.phase, RunPhase.Id.MAP, "全員が投票するまで進まない")
	assert_eq(run.state.players[0].vote, options[0].id)
	assert_true(run.vote(options[1].id, 2))
	assert_eq(run.state.node_id, options[1].id, "多い方へ")
	for p in run.state.players:
		assert_eq(p.vote, -1, "投票は消える")


func test_tied_vote_is_decided_by_rng_the_same_way_everywhere() -> void:
	var a := _coop(2, 9)
	var b := _coop(2, 9)
	var options := a.choices()
	if options.size() < 2:
		pass_test("この seed は選択肢が 1 つ")
		return
	for run: RunController in [a, b]:
		run.vote(options[0].id, 0)
		run.vote(options[1].id, 1)
	assert_ne(a.state.node_id, -1)
	assert_eq(a.state.node_id, b.state.node_id)


func test_combat_has_a_seat_per_player_and_downed_players_revive_at_one_hp() -> void:
	var run := _coop(2)
	_vote_all(run, F.force_next(run, MapNode.Type.BATTLE, &"jawworm"))
	assert_eq(run.state.phase, RunPhase.Id.COMBAT)
	var c := run.combat.combat
	assert_eq(c.seats.size(), 2)
	c.seats[1].unit.hp = 0
	c.finalize_death(c.seats[1].unit)
	F.win_combat(run)
	assert_true(run.acknowledge_combat_end())
	assert_eq(run.state.players[1].hp, 1, "倒れた人は HP 1 で復活")
	assert_eq(run.state.phase, RunPhase.Id.REWARD)
	assert_not_null(run.state.players[0].pending_reward)
	assert_not_null(run.state.players[1].pending_reward)
	assert_ne(run.state.players[0].pending_reward, run.state.players[1].pending_reward, "報酬は各自")


func test_everyone_downed_ends_the_run() -> void:
	var run := _coop(2)
	_vote_all(run, F.force_next(run, MapNode.Type.BATTLE, &"jawworm"))
	var c := run.combat.combat
	for s in c.seats:
		s.unit.hp = 0
		c.finalize_death(s.unit)
	assert_true(run.acknowledge_combat_end())
	assert_eq(run.state.phase, RunPhase.Id.DEFEAT)


func test_rewards_are_taken_individually_and_leaving_needs_everyone() -> void:
	var run := _coop(2)
	_vote_all(run, F.force_next(run, MapNode.Type.BATTLE, &"jawworm"))
	F.win_combat(run)
	run.acknowledge_combat_end()
	var gold_before := run.state.players[1].gold
	assert_true(run.take_reward(0, -1, 1), "ゴールドの行")
	assert_gt(run.state.players[1].gold, gold_before)
	assert_eq(run.state.players[0].gold, 99, "ほかの人は変わらない")
	assert_true(run.leave_node(0))
	assert_eq(run.state.phase, RunPhase.Id.REWARD, "1 人だけでは進まない")
	assert_true(run.cancel_leave(0))
	assert_false(run.state.players[0].done)
	run.leave_node(0)
	run.leave_node(1)
	assert_eq(run.state.phase, RunPhase.Id.MAP)


func test_shop_stock_is_per_player() -> void:
	var run := _coop(2)
	_vote_all(run, F.force_next(run, MapNode.Type.SHOP))
	assert_eq(run.state.phase, RunPhase.Id.SHOP)
	var s0 := run.state.players[0].shop
	var s1 := run.state.players[1].shop
	assert_not_null(s0)
	assert_not_null(s1)
	assert_ne(s0, s1)
	var i := -1
	for k in s1.items.size():
		if run.can_buy(k, 1):
			i = k
			break
	if i < 0:
		pass_test("買えるものが無い")
		return
	assert_true(run.buy(i, 1))
	assert_true(s1.items[i].sold)
	assert_eq(run.state.players[0].gold, 99)


func test_rest_is_per_player() -> void:
	var run := _coop(2)
	_vote_all(run, F.force_next(run, MapNode.Type.REST))
	run.state.players[0].hp = 40
	run.state.players[1].hp = 40
	assert_true(run.rest_heal(1))
	assert_gt(run.state.players[1].hp, 40)
	assert_eq(run.state.players[0].hp, 40)
	assert_false(run.can_leave(0), "まだ休んでいない人は進めない")
	assert_true(run.can_leave(1))


func test_event_choices_are_per_player_and_a_battle_choice_starts_it_for_everyone() -> void:
	var run := _coop(2)
	_vote_all(run, F.force_next(run, MapNode.Type.EVENT, &"sleeping_guardian"))
	assert_eq(run.state.phase, RunPhase.Id.EVENT)
	assert_not_null(run.choose_event_option(2, 0), "迂回する")
	assert_null(run.choose_event_option(2, 0), "同じ人は 2 回選べない")
	assert_not_null(run.choose_event_option(1, 1), "包みを開ける → 戦闘")
	assert_eq(run.state.players[0].event_choice, 2)
	assert_eq(run.state.players[1].event_choice, 1)
	run.leave_node(0)
	run.leave_node(1)
	assert_eq(run.state.phase, RunPhase.Id.COMBAT, "誰か 1 人が選べば全員で戦う")
	assert_eq(run.combat.combat.seats.size(), 2)


func test_coop_save_round_trip() -> void:
	var run := _coop(3)
	_vote_all(run, F.force_next(run, MapNode.Type.BATTLE, &"jawworm"))
	F.win_combat(run)
	run.acknowledge_combat_end()
	run.take_reward(0, -1, 2)
	var loaded := F.reload_state(run.state, _lib)
	assert_not_null(loaded)
	assert_eq(loaded.players.size(), 3)
	assert_eq(F.dump(loaded), F.dump(run.state))
	assert_eq(loaded.players[2].name, "P2")
	assert_eq(loaded.players[2].gold, run.state.players[2].gold)


func test_lockstep_two_controllers_stay_identical() -> void:
	# 同じシード・同じコマンド列なら、別の PC（= 別の RunController）でも同じ状態になる。
	var a := _coop(2, 21)
	var b := _coop(2, 21)
	for run: RunController in [a, b]:
		var node := F.force_next(run, MapNode.Type.BATTLE, &"jawworm")
		run.vote(node, 1)
		run.vote(node, 0)
		var c := run.combat
		for s in [1, 0]:
			var hand := c.seat_at(s).piles.hand.duplicate()
			for card: Card in hand:
				c.play_card(card, c.combat.alive_enemies()[0] if c.needs_target(card) else null, s)
		c.end_turn(0)
		c.end_turn(1)
	assert_eq(F.dump(a.state), F.dump(b.state))
	assert_eq(a.combat.combat.events.size(), b.combat.combat.events.size())
	assert_eq(a.combat.combat.seats[1].unit.hp, b.combat.combat.seats[1].unit.hp)

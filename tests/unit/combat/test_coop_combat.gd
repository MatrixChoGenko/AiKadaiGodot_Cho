extends GutTest
## 協力プレイの戦闘（GameDesign §21）：席ごとの山とエネルギー、Ready、敵の攻撃は全員へ、敵 HP の人数補正、倒れた人。

const T = preload("res://tests/support/builders/content_kit.gd")


## 席ごとに手札（この順に引く）を指定して、2〜4 人の戦闘を始める。
func _coop(hands: Array, enemy: EnemyData = null, hp: int = 80, relics: Array = []) -> CombatController:
	var setup := CombatSetup.new()
	setup.config = RunConfig.new()
	setup.rng = RngStreams.new(777)
	setup.keep_deck_order = true
	var encounter := EncounterData.new()
	encounter.id = &"coop_test"
	encounter.enemies.append(enemy if enemy != null else T.dummy(100))
	setup.encounter = encounter
	var uid := 1
	for i in hands.size():
		var ss := CombatSeatSetup.new()
		ss.name = "P%d" % i
		ss.hp = hp
		ss.max_hp = hp
		ss.draw_per_turn = (hands[i] as Array).size()
		var list: Array = hands[i]
		for j in range(list.size() - 1, -1, -1):
			ss.deck.append(Card.new(uid, list[j]))
			uid += 1
		if i < relics.size() and relics[i] != null:
			ss.relics.append(RelicSlot.new(relics[i]))
		setup.seats.append(ss)
	return CombatController.begin(setup)


func _card(ctl: CombatController, seat: int, id: StringName) -> Card:
	for c in ctl.combat.seats[seat].piles.hand:
		if c.data.id == id:
			return c
	return null


func test_each_seat_has_its_own_hand_and_energy() -> void:
	var ctl := _coop([[T.strike(), T.defend()], [T.defend(), T.filler()]])
	var c := ctl.combat
	assert_eq(c.seats.size(), 2)
	assert_eq(c.seats[0].piles.hand.size(), 2)
	assert_eq(c.seats[1].piles.hand.size(), 2)
	assert_eq(c.seats[0].turn.energy, 3)
	assert_eq(c.seats[1].turn.energy, 3)
	assert_ne(c.seats[0].unit.uid, c.seats[1].unit.uid, "プレイヤーの uid は別")
	assert_true(ctl.play_card(_card(ctl, 1, &"defend"), null, 1).ok)
	assert_eq(c.seats[1].turn.energy, 2, "席 1 だけが払う")
	assert_eq(c.seats[0].turn.energy, 3)
	assert_eq(c.seats[1].unit.block, 5)
	assert_eq(c.seats[0].unit.block, 0)
	assert_null(_card(ctl, 1, &"defend"), "席 1 の手札から出た")
	assert_not_null(_card(ctl, 0, &"defend"), "席 0 の手札は変わらない")


func test_enemy_hp_scales_with_player_count() -> void:
	assert_eq(_coop([[T.filler()]]).combat.enemies[0].max_hp, 100)
	assert_eq(_coop([[T.filler()], [T.filler()]]).combat.enemies[0].max_hp, 175)
	assert_eq(_coop([[T.filler()], [T.filler()], [T.filler()], [T.filler()]]).combat.enemies[0].max_hp, 325)


func test_enemy_turn_waits_until_everyone_is_ready_and_ready_can_be_cancelled() -> void:
	var ctl := _coop([[T.strike()], [T.strike()]], T.attacker(8))
	var c := ctl.combat
	assert_true(ctl.end_turn(0))
	assert_eq(c.turn.phase, TurnState.Phase.PLAYER, "1 人だけでは敵のターンにならない")
	assert_eq(c.seats[0].turn.number, 1)
	assert_false(ctl.play_card(_card(ctl, 0, &"strike"), c.enemies[0], 0).ok, "Ready の人はカードを出せない")
	assert_true(ctl.cancel_ready(0))
	assert_true(ctl.play_card(_card(ctl, 0, &"strike"), c.enemies[0], 0).ok, "取り消したら出せる")
	assert_true(ctl.end_turn(0))
	assert_true(ctl.end_turn(1))
	assert_eq(c.seats[0].turn.number, 2, "全員が Ready → 敵のターン → 次のターン")
	assert_eq(c.seats[1].turn.number, 2)
	assert_false(c.seats[0].ready, "新しいターンで Ready は外れる")


func test_enemy_attack_hits_every_player_but_self_buffs_once() -> void:
	var foe := T.enemy(&"brute", 100, [T.move(&"smash", [T.block(6), T.dmg(8)])])
	var ctl := _coop([[T.filler()], [T.filler()], [T.filler()]], foe)
	var c := ctl.combat
	for i in 3:
		ctl.end_turn(i)
	for s in c.seats:
		assert_eq(s.unit.hp, 72, "攻撃は全員に当たる")
	assert_eq(c.enemies[0].block, 6, "自分へのブロックは 1 回だけ")


func test_enemy_card_creation_goes_to_each_players_discard() -> void:
	var junk := T.card(&"junk", 1, [], {cost_mode = CardData.CostMode.UNPLAYABLE, type = CardData.Type.STATUS})
	var foe := T.enemy(&"spitter", 100, [T.move(&"spit", [T.create(junk, Pile.Place.DISCARD, 2)])])
	var ctl := _coop([[T.filler()], [T.filler()]], foe)
	ctl.end_turn(0)
	ctl.end_turn(1)
	for s in ctl.combat.seats:
		var n := 0
		for card in s.piles.all_cards():
			if card.data.id == &"junk":
				n += 1
		assert_eq(n, 2, "席 %d の山に 2 枚" % s.index)


func test_relics_only_react_for_their_owner() -> void:
	var lantern := T.relic(&"lantern", TurnResources.new())
	(lantern.behaviors[0] as TurnResources).energy = 1
	var ctl := _coop([[T.filler()], [T.filler()]], null, 80, [null, lantern])
	assert_eq(ctl.combat.seats[0].turn.energy, 3)
	assert_eq(ctl.combat.seats[1].turn.energy, 4, "提灯は持ち主のエネルギーだけ")


func test_downed_player_spectates_and_combat_continues() -> void:
	var ctl := _coop([[T.filler()], [T.filler()]], T.attacker(10), 80)
	var c := ctl.combat
	c.seats[0].unit.hp = 5
	ctl.end_turn(0)
	ctl.end_turn(1)
	assert_false(c.seats[0].is_alive(), "席 0 は倒れた")
	assert_false(c.is_over(), "1 人残っていれば続く")
	assert_true(c.seats[0].ready, "倒れた人は Ready 扱い")
	assert_true(ctl.end_turn(1), "残った人だけで敵のターンへ")
	assert_eq(c.seats[1].unit.hp, 60)
	assert_true(ctl.result_for(0).downed)
	assert_false(ctl.result_for(1).downed)


func test_everyone_downed_is_defeat() -> void:
	var ctl := _coop([[T.filler()], [T.filler()]], T.attacker(50), 40)
	ctl.end_turn(0)
	ctl.end_turn(1)
	assert_true(ctl.is_over())
	assert_eq(ctl.combat.outcome, Combat.Outcome.DEFEAT)


func test_card_choice_belongs_to_the_player_who_played_it() -> void:
	var picker := T.card(&"picker", 0, [T.choose(Pile.Id.HAND, ChooseCardsEffect.Action.DISCARD, 1)])
	var ctl := _coop([[picker, T.filler(&"a"), T.filler(&"c")], [T.strike(), T.filler(&"b")]])
	var c := ctl.combat
	assert_true(ctl.play_card(_card(ctl, 0, &"picker"), null, 0).ok)
	assert_not_null(ctl.pending_choice())
	assert_eq(c.choice_seat(), c.seats[0])
	assert_false(ctl.play_card(_card(ctl, 1, &"strike"), c.enemies[0], 1).ok, "選択待ちの間はほかの人も待つ")
	var b: Array[Card] = [_card(ctl, 1, &"b")]
	assert_false(ctl.submit_choice(b, 1), "ほかの人は答えられない")
	var a: Array[Card] = [_card(ctl, 0, &"a")]
	assert_true(ctl.submit_choice(a, 0))
	assert_eq(c.seats[0].piles.discard.size(), 2, "picker と a")
	assert_true(ctl.play_card(_card(ctl, 1, &"strike"), c.enemies[0], 1).ok)


func test_same_commands_give_same_state() -> void:
	# ロックステップの前提：同じシードと同じコマンドの列なら、どの PC でも同じ結果になる。
	var deck := [T.strike(), T.strike(), T.defend(), T.defend(), T.filler()]
	var a := _coop([deck, deck], T.attacker(7))
	var b := _coop([deck, deck], T.attacker(7))
	for ctl: CombatController in [a, b]:
		ctl.play_card(_card(ctl, 1, &"strike"), ctl.combat.enemies[0], 1)
		ctl.play_card(_card(ctl, 0, &"defend"), null, 0)
		ctl.end_turn(1)
		ctl.end_turn(0)
	assert_eq(a.combat.events.size(), b.combat.events.size())
	assert_eq(a.combat.enemies[0].hp, b.combat.enemies[0].hp)
	assert_eq(a.combat.rng.save(), b.combat.rng.save())

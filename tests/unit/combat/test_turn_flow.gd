extends GutTest
## ターンの流れ・山・減衰（GameDesign §5.2 / §5.4 / §5.7 / §8、付録 C）。

const T = preload("res://tests/support/builders/content_kit.gd")


func test_turn_one_keeps_combat_start_block_turn_two_clears() -> void:
	var anchor := T.relic(&"anchor", CombatStartResources.new())
	(anchor.behaviors[0] as CombatStartResources).block = 10
	var h := CombatBuilder.new().with_hand([T.filler()]).with_relic(anchor).build()
	assert_eq(h.player().block, 10, "第 1 ターンは消えない（C1）")
	h.end_turn()
	assert_eq(h.player().block, 0, "第 2 ターン開始で消える")


func test_turn_ending_comes_before_hand_cleanup() -> void:
	var h := CombatBuilder.new().with_hand([T.filler(&"a"), T.filler(&"b")]).build()
	var start := h.combat.events.size()
	h.end_turn()
	var kinds: Array[CombatEvent.Kind] = []
	for e: CombatEvent in h.combat.events.slice(start):
		kinds.append(e.kind)
	var ending := kinds.find(CombatEvent.Kind.TURN_ENDING)
	assert_eq(ending, 0, "ターン終了を押した瞬間に最初に出る（表現層が敵のターンの合図を出す）")
	assert_lt(ending, kinds.find(CombatEvent.Kind.CARD_DISCARDED), "手札の後始末より前")
	assert_lt(kinds.find(CombatEvent.Kind.CARD_DISCARDED), kinds.find(CombatEvent.Kind.TURN_ENDED))
	assert_eq(h.events_of(CombatEvent.Kind.TURN_ENDING)[0].value, 1, "終わるターンの番号")


func test_barricade_keeps_block() -> void:
	var h := CombatBuilder.new().with_hand([T.defend(7)]).build()
	h.add_status(h.player(), &"barricade", 1)
	h.play(&"defend")
	h.end_turn()
	assert_eq(h.player().block, 7)


func test_energy_resets_each_turn_and_relic_bonus() -> void:
	var lantern := T.relic(&"lantern", TurnResources.new())
	(lantern.behaviors[0] as TurnResources).energy = 1
	(lantern.behaviors[0] as TurnResources).first_turn_only = true
	var h := CombatBuilder.new().with_hand([T.strike()]).with_relic(lantern).build()
	assert_eq(h.combat.turn.energy, 4, "提灯：第 1 ターン +1")
	h.play(&"strike")
	h.end_turn()
	assert_eq(h.combat.turn.energy, 3, "第 2 ターンは元に戻る（複利にならない）")


func test_draw_reshuffles_discard_when_empty() -> void:
	var h := CombatBuilder.new().with_hand([T.filler(&"a"), T.filler(&"b")]).with_draw_per_turn(2).build()
	assert_eq(h.hand().size(), 2)
	h.end_turn()
	assert_eq(h.hand().size(), 2, "捨て札をシャッフルして引き直す")
	assert_eq(h.events_of(CombatEvent.Kind.PILE_SHUFFLED).size(), 1)


func test_hand_limit_overflow_goes_to_discard() -> void:
	var cards: Array = []
	for i in 12:
		cards.append(T.filler(StringName("f%d" % i)))
	var h := CombatBuilder.new().with_hand(cards).build()
	assert_eq(h.hand().size(), 10)
	assert_eq(h.combat.piles.discard.size(), 2)


func test_innate_goes_on_top() -> void:
	var innate := T.card(&"innate", 0, [], {kw = CardData.Keyword.INNATE})
	var h := CombatBuilder.new().with_hand([T.filler(&"x")]).with_draw_pile([T.filler(&"y"), innate]).build()
	assert_true(h.hand_ids().has(&"innate"), "天賦は山札の一番上に置かれて第 1 ターンに引かれる")


func test_end_of_turn_hand_cleanup() -> void:
	var ethereal := T.card(&"eth", 0, [], {kw = CardData.Keyword.ETHEREAL})
	var retain := T.card(&"ret", 0, [], {kw = CardData.Keyword.RETAIN})
	var h := CombatBuilder.new().with_hand([ethereal, retain, T.filler()]).with_draw_per_turn(0).build()
	h.end_turn()
	assert_eq(h.combat.piles.exhaust.size(), 1, "エセリアルは廃棄")
	assert_eq(h.hand_ids(), [&"ret"] as Array[StringName], "保留は残る")
	assert_eq(h.card(&"ret").retained_turns, 1)
	assert_eq(h.combat.piles.discard.size(), 1)


func test_end_of_turn_discard_triggers_on_discard() -> void:
	# GameDesign §5.4：ターン終了時の手札の捨て札も「捨てられた時」を発動する。
	var tremor := T.card(&"tremor", 1, [], {on_discard = [T.dmg(8, T.random_enemy(), null, &"")]})
	var h := CombatBuilder.new().with_hand([tremor]).build()
	h.end_turn()
	assert_eq(h.enemy().hp, 92)


func test_end_of_turn_in_hand_effect() -> void:
	var burn := T.card(&"burn", 0, [], {cost_mode = CardData.CostMode.UNPLAYABLE, end_of_turn = [T.lose_hp(2)]})
	var h := CombatBuilder.new().with_hand([burn]).build()
	h.end_turn()
	assert_eq(h.player().hp, 78)


func test_weak_on_enemy_lasts_through_its_attack() -> void:
	# C2：ラウンド終了時（敵のターンの後）に -1。プレイヤーが付けた弱体 1 は敵の攻撃に効く。
	var weaken := T.card(&"weaken", 0, [T.apply(&"weak", 1)])
	var h := CombatBuilder.new().with_hand([weaken]).with_enemy(T.attacker(8)).build()
	h.play(&"weaken")
	h.end_turn()
	assert_eq(h.player().hp, 74, "8 × 0.75 = 6")
	assert_eq(h.stacks(h.enemy(), &"weak"), 0, "ラウンド終了で 0")


func test_enemy_applied_vulnerable_skips_first_round_decay() -> void:
	# C2：敵のターン中に付与されたスタックはそのラウンドの減衰を受けない。脆弱 2 なら敵の攻撃 2 回に効く。
	var e := T.enemy(&"stomper", 100, [T.move(&"stomp", [T.dmg(8), T.apply(&"vulnerable", 2)])])
	var h := CombatBuilder.new().with_hand([T.filler()]).with_enemy(e).build()
	h.end_turn()   # 8（付与前）
	assert_eq(h.stacks(h.player(), &"vulnerable"), 2, "付与したラウンドは減らない")
	h.end_turn()   # 12
	h.end_turn()   # 12（2 回目まで効く）
	assert_eq(h.player().hp, 80 - 8 - 12 - 12)


func test_poison_ticks_and_decrements_once() -> void:
	var h := CombatBuilder.new().with_hand([T.card(&"p", 0, [T.apply(&"poison", 5)])]).build()
	h.play(&"p")
	h.end_turn()
	assert_eq(h.enemy().hp, 95)
	assert_eq(h.stacks(h.enemy(), &"poison"), 4, "1 ターンに 1 だけ減る（C3）")


func test_poison_ignores_block() -> void:
	var h := CombatBuilder.new().with_hand([T.card(&"p", 0, [T.apply(&"poison", 3)])]).build()
	h.enemy().block = 50
	h.play(&"p")
	h.end_turn()
	assert_eq(h.enemy().hp, 97)


func test_turn_limit_is_defeat() -> void:
	var cfg := RunConfig.new()
	cfg.turn_limit = 3
	var h := CombatBuilder.new().with_hand([T.filler()]).with_config(cfg).build()
	for i in 5:
		h.end_turn()
	assert_eq(h.combat.outcome, Combat.Outcome.DEFEAT)


func test_player_death_ends_combat_before_next_turn() -> void:
	var h := CombatBuilder.new().with_hand([T.filler()]).with_player(5).with_enemy(T.attacker(10)).build()
	h.end_turn()
	assert_eq(h.combat.outcome, Combat.Outcome.DEFEAT)
	assert_eq(h.events_of(CombatEvent.Kind.TURN_STARTED).size(), 1, "死んだ後に次のターンが始まらない")


func test_demon_form_grants_strength_each_turn() -> void:
	var h := CombatBuilder.new().with_hand([T.filler()]).build()
	h.add_status(h.player(), &"demon_form", 1)
	h.end_turn()
	assert_eq(h.stacks(h.player(), &"strength"), 2)
	h.end_turn()
	assert_eq(h.stacks(h.player(), &"strength"), 4)

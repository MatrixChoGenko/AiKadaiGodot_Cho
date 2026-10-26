extends GutTest
## カードのプレイ（GameDesign §5.3 / Architecture §7.5）。

const T = preload("res://tests/support/builders/content_kit.gd")


func test_play_rejections() -> void:
	var expensive := T.card(&"big", 5, [])
	var unplayable := T.card(&"wound", 0, [], {cost_mode = CardData.CostMode.UNPLAYABLE})
	var h := CombatBuilder.new().with_hand([T.strike(), expensive, unplayable]).build()
	assert_eq(h.ctl.check_card(h.card(&"strike")).reason, PlayResult.NEED_TARGET)
	assert_eq(h.ctl.check_card(h.card(&"strike"), h.player()).reason, PlayResult.INVALID_TARGET)
	assert_eq(h.ctl.check_card(h.card(&"big")).reason, PlayResult.NOT_ENOUGH_ENERGY)
	assert_eq(h.ctl.check_card(h.card(&"wound")).reason, PlayResult.UNPLAYABLE)


func test_destinations() -> void:
	var power := T.card(&"power", 0, [], {type = CardData.Type.POWER})
	var exhaust := T.card(&"exh", 0, [], {kw = CardData.Keyword.EXHAUST})
	var h := CombatBuilder.new().with_hand([power, exhaust, T.filler()]).build()
	h.play(&"power")
	h.play(&"exh")
	h.play(&"filler")
	assert_eq(h.combat.piles.powers.size(), 1)
	assert_eq(h.combat.piles.exhaust.size(), 1)
	assert_eq(h.combat.piles.discard.size(), 1)
	assert_true(h.cards_conserved())


func test_temporary_card_is_exhausted_after_play() -> void:
	var strike := T.strike()
	var make := T.card(&"make", 0, [T.create(strike, Pile.Place.HAND, 1)])
	var h := CombatBuilder.new().with_hand([make]).build()
	h.play(&"make")
	assert_true(h.card(&"strike").temporary)
	h.play(&"strike")
	assert_eq(h.combat.piles.exhaust.size(), 1)
	assert_true(h.cards_conserved())


func test_x_cost_spends_all() -> void:
	var x := T.card(&"whirl", 0, [T.dmg(5, T.all_enemies(), XValue.new())], {cost_mode = CardData.CostMode.X, type = CardData.Type.ATTACK})
	var h := CombatBuilder.new().with_hand([x]).with_energy(3).build()
	h.play(&"whirl")
	assert_eq(h.combat.turn.energy, 0)
	assert_eq(h.enemy().hp, 85, "5 × 3 回")


func test_echo_relic_resolves_first_attack_twice() -> void:
	var h := CombatBuilder.new().with_hand([T.strike(6), T.strike(6)]) \
		.with_relic(T.relic(&"echo", FirstCardOfTypeEcho.new())).build()
	h.play(&"strike")
	assert_eq(h.enemy().hp, 88, "1 枚目は 2 回解決")
	h.play(&"strike")
	assert_eq(h.enemy().hp, 82, "2 枚目は 1 回")


func test_pen_nib_first_attack_costs_less() -> void:
	var h := CombatBuilder.new().with_hand([T.strike(), T.strike()]) \
		.with_relic(T.relic(&"pen_nib", FirstCardOfTypeCostDown.new())).build()
	assert_eq(h.ctl.cost_of(h.hand()[0]), 0)
	h.play(&"strike")
	assert_eq(h.combat.turn.energy, 3)
	assert_eq(h.ctl.cost_of(h.hand()[0]), 1)


func test_recycler_sends_skills_to_draw_pile() -> void:
	var h := CombatBuilder.new().with_hand([T.defend()]).with_relic(T.relic(&"recycler", RedirectCardDestination.new())).build()
	h.play(&"defend")
	assert_eq(h.combat.piles.draw.size(), 1)
	assert_eq(h.combat.piles.discard.size(), 0)


func test_played_card_is_not_counted_in_hand() -> void:
	var ambush := T.card(&"ambush", 0, [T.dmg(T.scaled(0, 3, HandCountValue.new()))], {type = CardData.Type.ATTACK})
	var h := CombatBuilder.new().with_hand([ambush, T.filler(&"a"), T.filler(&"b")]).build()
	h.play(&"ambush")
	assert_eq(h.enemy().hp, 94, "自分を除く手札 2 枚 × 3")


func test_last_card_type_and_played_count() -> void:
	var follow := T.card(&"follow", 0, [])
	var branch := BranchEffect.new()
	var cond := LastCardTypeCondition.new()
	branch.when = cond
	branch.then.assign([T.draw(1)])
	follow.on_play.assign([branch])
	var h := CombatBuilder.new().with_hand([T.strike(), follow]).with_draw_pile([T.filler()]).with_draw_per_turn(2).build()
	h.play(&"strike")
	h.play(&"follow")
	assert_eq(h.hand_ids(), [&"filler"] as Array[StringName], "直前がアタックなので 1 枚引いた")
	assert_eq(h.combat.turn.played_count(0), 2)


func test_potion_use_and_slot_emptied() -> void:
	var fire := PotionData.new()
	fire.id = &"fire"
	fire.aim = CardData.Aim.ENEMY
	fire.effects.assign([T.dmg(20)])
	var h := CombatBuilder.new().with_hand([T.filler()]).with_potions([fire, null]).build()
	assert_eq(h.ctl.check_potion(0).reason, PlayResult.NEED_TARGET)
	assert_eq(h.ctl.check_potion(1, h.enemy()).reason, PlayResult.NO_POTION)
	assert_true(h.ctl.use_potion(0, h.enemy()).ok)
	assert_eq(h.enemy().hp, 80)
	assert_null(h.combat.potions[0])


func test_victory_relic_rewards() -> void:
	var blood := T.relic(&"burning_blood", VictoryRewards.new())
	(blood.behaviors[0] as VictoryRewards).heal = 6
	(blood.behaviors[0] as VictoryRewards).gold = 12
	var h := CombatBuilder.new().with_hand([T.strike(50)]).with_enemy(T.dummy(50)).with_player(50, 80).with_relic(blood).build()
	h.play(&"strike")
	var r := h.ctl.result()
	assert_true(r.victory)
	assert_eq(r.hp, 56)
	assert_eq(r.gold_gained, 12)

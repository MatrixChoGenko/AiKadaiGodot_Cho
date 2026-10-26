extends GutTest
## 効果ブロック（原子効果・コンビネータ・値の出所・対象ルール）の振る舞い。

const T = preload("res://tests/support/builders/content_kit.gd")


func test_repeat_with_random_target() -> void:
	var dance := T.card(&"dance", 0, [T.repeat(3, [T.dmg(4, T.random_enemy())])], {type = CardData.Type.ATTACK})
	var h := CombatBuilder.new().with_hand([dance]).with_enemy(T.dummy(50)).with_enemy(T.dummy(50)).build()
	h.play(&"dance")
	assert_eq(100 - h.enemy(0).hp - h.enemy(1).hp, 12 - 0, "合計 12 ダメージ")


func test_branch_on_condition() -> void:
	var cond := HpBelowPercentCondition.new()
	cond.on = ValueSource.On.TARGET
	var finisher_value := IfValue.new()
	finisher_value.when = cond
	finisher_value.then = T.v(20)
	finisher_value.otherwise = T.v(10)
	var finisher := T.card(&"fin", 0, [T.dmg(finisher_value)], {type = CardData.Type.ATTACK})
	var h := CombatBuilder.new().with_hand([finisher, finisher]).with_enemy(T.dummy(100)).build()
	h.play(&"fin")
	assert_eq(h.enemy().hp, 90)
	h.enemy().hp = 40
	h.play(&"fin")
	assert_eq(h.enemy().hp, 20)


func test_defer_end_of_turn_and_next_turn() -> void:
	var bomb := T.card(&"bomb", 0, [T.defer(DeferEffect.Timing.END_OF_THIS_TURN, [T.dmg(14, T.all_enemies())])])
	var gather := T.card(&"gather", 0, [T.defer(DeferEffect.Timing.START_OF_NEXT_TURN, [T.block(8)])])
	var h := CombatBuilder.new().with_hand([bomb, gather]).build()
	h.play(&"bomb")
	h.play(&"gather")
	assert_eq(h.enemy().hp, 100, "まだ発動しない")
	assert_eq(h.player().block, 0)
	h.end_turn()
	assert_eq(h.enemy().hp, 86, "ターン終了時に発動")
	assert_eq(h.player().block, 8, "次のターン開始時に発動（ブロック消去の後）")


func test_consume_then_scale() -> void:
	var consume := ConsumeStatusEffect.new()
	consume.status = T.status(&"poison")
	consume.target = T.chosen()
	var det := T.card(&"det", 0, [consume, T.dmg(T.scaled(0, 3, T.stat(ResolveStatValue.Stat.CONSUMED_STACKS)))],
		{type = CardData.Type.ATTACK})
	var h := CombatBuilder.new().with_hand([det]).build()
	h.add_status(h.enemy(), &"poison", 7)
	h.play(&"det")
	assert_eq(h.stacks(h.enemy(), &"poison"), 0)
	assert_eq(h.enemy().hp, 79)


func test_spread_to_other_enemies() -> void:
	var spread := SpreadStatusEffect.new()
	spread.status = T.status(&"poison")
	spread.target = T.chosen()
	var others := AllEnemiesTarget.new()
	others.exclude_chosen = true
	spread.spread_to = others
	spread.percent = 50
	var h := CombatBuilder.new().with_hand([T.card(&"inf", 0, [spread])]) \
		.with_enemy(T.dummy()).with_enemy(T.dummy()).with_enemy(T.dummy()).build()
	h.add_status(h.enemy(0), &"poison", 9)
	h.play(&"inf", h.enemy(0))
	assert_eq(h.stacks(h.enemy(0), &"poison"), 9)
	assert_eq(h.stacks(h.enemy(1), &"poison"), 4)
	assert_eq(h.stacks(h.enemy(2), &"poison"), 4)


func test_discard_all_counts_cards() -> void:
	var discard := DiscardEffect.new()
	var cast := T.card(&"cast", 0, [discard, T.dmg(T.scaled(0, 4, T.stat(ResolveStatValue.Stat.CARDS_AFFECTED)), T.all_enemies())],
		{type = CardData.Type.ATTACK})
	var h := CombatBuilder.new().with_hand([cast, T.filler(&"a"), T.filler(&"b"), T.filler(&"c")]).build()
	h.play(&"cast")
	assert_eq(h.enemy().hp, 88)
	assert_true(h.hand().is_empty())


func test_cost_reduction_this_turn() -> void:
	var feast := ModifyCostEffect.new()
	var h := CombatBuilder.new().with_hand([T.card(&"feast", 0, [feast]), T.strike()]).with_draw_per_turn(0).build()
	h.play(&"feast")
	assert_eq(h.ctl.cost_of(h.card(&"strike")), 0)
	h.end_turn()
	assert_eq(h.ctl.cost_of(h.combat.piles.discard[1]), 1, "このターンだけ")


func test_grow_persists_within_combat() -> void:
	var grow := GrowCardEffect.new()
	grow.amount = 3
	var honed := T.card(&"honed", 0, [T.dmg(T.scaled(5, 1, CardGrowthValue.new())), grow], {type = CardData.Type.ATTACK})
	var h := CombatBuilder.new().with_hand([honed]).build()
	h.play(&"honed")
	h.end_turn()
	h.play(&"honed")
	assert_eq(h.enemy().hp, 100 - 5 - 8)


func test_siphon_heals_damage_dealt() -> void:
	var heal := HealEffect.new()
	heal.amount = T.stat(ResolveStatValue.Stat.DAMAGE_DEALT)
	var siphon := T.card(&"siphon", 0, [T.dmg(9), heal], {type = CardData.Type.ATTACK})
	var h := CombatBuilder.new().with_hand([siphon]).with_player(50, 80).build()
	h.enemy().block = 4
	h.play(&"siphon")
	assert_eq(h.player().hp, 55, "ブロックに吸われた分は数えない")


func test_artifact_negates_debuff() -> void:
	var h := CombatBuilder.new().with_hand([T.card(&"w", 0, [T.apply(&"weak", 2)])]).build()
	h.add_status(h.enemy(), &"artifact", 1)
	h.play(&"w")
	assert_eq(h.stacks(h.enemy(), &"weak"), 0)
	assert_eq(h.stacks(h.enemy(), &"artifact"), 0)


func test_create_cards_into_discard() -> void:
	var wound := T.card(&"wound", 0, [], {cost_mode = CardData.CostMode.UNPLAYABLE})
	var h := CombatBuilder.new().with_hand([T.card(&"bargain", 0, [T.create(wound, Pile.Place.DISCARD, 2), T.energy(2)])]).build()
	h.play(&"bargain")
	assert_eq(h.combat.turn.energy, 5)
	assert_eq(h.combat.piles.discard.size(), 3)
	assert_true(h.cards_conserved())


func test_exhaust_trigger_fires() -> void:
	var ember := T.card(&"ember", 0, [], {kw = CardData.Keyword.EXHAUST, on_exhaust = [T.energy(1)]})
	var h := CombatBuilder.new().with_hand([ember]).build()
	h.play(&"ember")
	assert_eq(h.combat.turn.energy, 4)

extends GutTest
## RunEffect / RunCondition の全サブクラス（GameDesign §7.5）。

var _lib: ContentLibrary


func before_all() -> void:
	_lib = OfficialSetup.library()


func _ctx(hp: int = 50, max_hp: int = 80, gold: int = 100) -> RunEffectContext:
	var s := RunState.new()
	s.rng = RngStreams.new(3)
	s.hp = hp
	s.max_hp = max_hp
	s.gold = gold
	s.potions = PotionBelt.new(3)
	for id: StringName in [&"strike", &"strike", &"defend", &"bash"]:
		s.deck.add(_lib.card(id))
	return RunEffectContext.new(s, _lib, _lib.config, 1)


func test_gold() -> void:
	var c := _ctx(50, 80, 30)
	var e := GoldRunEffect.new()
	e.amount = -50
	e.apply(c)
	assert_eq(c.state.gold, 0, "gold does not go below 0")
	e.amount = 25
	e.apply(c)
	assert_eq(c.state.gold, 25)


func test_hp_constant_and_percent_never_kill() -> void:
	var c := _ctx(10, 80)
	var e := HpRunEffect.new()
	e.amount = -12
	e.apply(c)
	assert_eq(c.state.hp, 1, "event HP loss leaves at least 1")
	e.amount = 200
	e.apply(c)
	assert_eq(c.state.hp, 80, "capped at max")
	e.amount = -25
	e.percent_of_max = true
	e.apply(c)
	assert_eq(c.state.hp, 60)


func test_max_hp_and_heal_missing() -> void:
	var c := _ctx(40, 80)
	var e := MaxHpRunEffect.new()
	e.amount = 5
	e.apply(c)
	assert_eq([c.state.hp, c.state.max_hp], [45, 85])
	e.heal_too = false
	e.apply(c)
	assert_eq([c.state.hp, c.state.max_hp], [45, 90])
	var h := HealMissingPercentRunEffect.new()
	h.percent = 40
	h.apply(c)
	assert_eq(c.state.hp, 45 + 18, "40% of 45 missing = 18")


func test_add_card_fixed_random_and_choice() -> void:
	var c := _ctx()
	var fixed := AddCardRunEffect.new()
	fixed.card = _lib.card(&"doubt")
	fixed.count = 2
	fixed.apply(c)
	assert_eq(c.state.deck.size(), 6)
	assert_eq(c.state.deck.cards[5].data.id, &"doubt")
	var uids := c.state.deck.cards.map(func(x: Card) -> int: return x.uid)
	assert_eq(uids, [1, 2, 3, 4, 5, 6], "uids are unique and increasing")

	var random := AddCardRunEffect.new()
	random.pool = AddCardRunEffect.Pool.RARE
	random.apply(c)
	assert_eq(c.state.deck.size(), 7)
	assert_eq(c.state.deck.cards[6].data.rarity, CardData.Rarity.RARE)

	var choice := AddCardRunEffect.new()
	choice.pool = AddCardRunEffect.Pool.ANY_RARITY
	choice.choose_from = 3
	choice.apply(c)
	assert_eq(c.state.deck.size(), 7, "choice does not add directly")
	assert_eq(c.requests.size(), 1)
	var req := c.requests[0]
	assert_eq(req.kind, RunChoiceRequest.Kind.PICK)
	assert_eq(req.offers.size(), 3)
	var ids := {}
	for o in req.offers:
		ids[o.id] = true
		assert_true(_lib.reward_pool().has(o))
	assert_eq(ids.size(), 3, "offers are distinct")


func test_remove_and_upgrade_make_requests() -> void:
	var c := _ctx()
	RemoveCardRunEffect.new().apply(c)
	UpgradeCardRunEffect.new().apply(c)
	assert_eq(c.requests.map(func(r: RunChoiceRequest) -> int: return r.kind),
			[RunChoiceRequest.Kind.REMOVE, RunChoiceRequest.Kind.UPGRADE])


func test_gain_relic_excludes_owned() -> void:
	var c := _ctx()
	var fixed := GainRelicRunEffect.new()
	fixed.pool = GainRelicRunEffect.Pool.FIXED
	fixed.relic = _lib.relic(&"anchor")
	fixed.apply(c)
	fixed.apply(c)
	assert_eq(c.state.relics.size(), 1, "an owned relic is not gained twice")
	var boss := GainRelicRunEffect.new()
	boss.pool = GainRelicRunEffect.Pool.BOSS
	boss.apply(c)
	boss.apply(c)
	boss.apply(c)
	assert_eq(c.state.relics.size(), 3, "only 2 boss relics exist")
	var any := GainRelicRunEffect.new()
	for i in 30:
		any.apply(c)
	var ids := {}
	for r in c.state.relics:
		ids[r.data.id] = true
		assert_ne(r.data.rarity, RelicData.Rarity.STARTER)
	assert_eq(ids.size(), c.state.relics.size(), "no duplicates")


func test_potions_and_slots() -> void:
	var c := _ctx()
	var e := GainPotionRunEffect.new()
	for i in 4:
		e.apply(c)
	assert_eq(c.state.potions.count(), 3, "a full belt loses the potion")
	var slots := PotionSlotsRunEffect.new()
	slots.delta = 1
	slots.apply(c)
	assert_eq(c.state.potions.slots.size(), 4)
	slots.delta = -2
	slots.apply(c)
	assert_eq(c.state.potions.slots.size(), 2)
	assert_eq(c.state.potions.count(), 2)


func test_branch_and_random() -> void:
	var c := _ctx(30, 80)
	var low := HpBelowPercentRunCondition.new()
	low.percent = 50
	var b := BranchRunEffect.new()
	b.when = low
	var g1 := GoldRunEffect.new()
	g1.amount = 1
	var g2 := GoldRunEffect.new()
	g2.amount = 1000
	b.then.assign([g1])
	b.otherwise.assign([g2])
	b.apply(c)
	assert_eq(c.state.gold, 101)
	c.state.hp = 40
	b.apply(c)
	assert_eq(c.state.gold, 1101, "40 / 80 is not below 50%")

	var r := RandomRunEffect.new()
	r.percent = 50
	r.then.assign([g1])
	r.otherwise.assign([])
	var before := c.state.rng.save()
	var hits := 0
	for i in 200:
		var gold := c.state.gold
		r.apply(c)
		hits += c.state.gold - gold
	assert_between(hits, 70, 130, "about 50%")
	assert_ne(c.state.rng.save()["event"], before["event"], "uses the event stream")
	assert_eq(c.state.rng.save()["reward"], before["reward"])


func test_start_battle_queues_an_encounter() -> void:
	var c := _ctx()
	var e := StartBattleRunEffect.new()
	e.rewards = false
	e.apply(c)
	var enc := _lib.encounter(c.state.queued_encounter)
	assert_not_null(enc)
	assert_eq(enc.rank, EnemyData.Rank.NORMAL)
	assert_false(c.state.queued_encounter_rewards)
	e.encounter = _lib.encounter(&"gremlin_nob")
	e.apply(c)
	assert_eq(c.state.queued_encounter, &"gremlin_nob")


func test_conditions() -> void:
	var c := _ctx(30, 80, 60)
	var gold := GoldAtLeastRunCondition.new()
	gold.value = 60
	assert_true(gold.test(c))
	gold.value = 61
	assert_false(gold.test(c))
	gold.negate = true
	assert_true(gold.test(c), "negate")

	var hp := HpAtLeastRunCondition.new()
	hp.value = 30
	assert_true(hp.test(c))
	var low := HpBelowPercentRunCondition.new()
	low.percent = 50
	assert_true(low.test(c))

	var deck := DeckSizeAtLeastRunCondition.new()
	deck.value = 4
	assert_true(deck.test(c))
	deck.value = 5
	assert_false(deck.test(c))

	var won := BattlesWonAtLeastRunCondition.new()
	won.value = 1
	assert_false(won.test(c))
	c.state.battles_won = 1
	assert_true(won.test(c))

	var relic := HasRelicRunCondition.new()
	relic.relic = _lib.relic(&"anchor")
	assert_false(relic.test(c))
	c.state.add_relic(relic.relic)
	assert_true(relic.test(c))

	var card := HasCardRunCondition.new()
	card.card = _lib.card(&"bash")
	assert_true(card.test(c))
	c.state.deck.cards[3].upgrade()
	assert_true(card.test(c), "an upgraded copy counts")
	card.card = _lib.card(&"cleave")
	assert_false(card.test(c))

	var upgradable := HasUpgradableCardRunCondition.new()
	assert_true(upgradable.test(c))
	for x in c.state.deck.cards:
		x.upgrade()
	assert_false(upgradable.test(c))

	var all := AllOfRunCondition.new()
	all.conditions.assign([hp, low])
	assert_true(all.test(c))
	all.conditions.append(upgradable)
	assert_false(all.test(c))

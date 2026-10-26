extends GutTest
## RunController：ラン進行のステートマシン（Architecture §10.2・§10.3、GameDesign §3・§12）。

var _lib: ContentLibrary
var _checkpoints: Array[StringName] = []
var _phases: Array[RunPhase.Id] = []


func before_all() -> void:
	_lib = OfficialSetup.library()


func before_each() -> void:
	_checkpoints.clear()
	_phases.clear()


func _run(lib: ContentLibrary = _lib, seed_value: int = 1, cfg: RunConfig = null) -> RunController:
	var run := RunController.new(lib, cfg)
	run.checkpoint_reached.connect(_on_checkpoint)
	run.phase_changed.connect(_on_phase)
	run.start_new(seed_value)
	return run


func _on_checkpoint(reason: StringName) -> void:
	_checkpoints.append(reason)


func _on_phase(phase: RunPhase.Id) -> void:
	_phases.append(phase)


# —— 開始 ——

func test_start_new_uses_run_config() -> void:
	var run := _run()
	var s := run.state
	assert_eq([s.hp, s.max_hp, s.gold, s.energy_per_turn, s.draw_per_turn], [80, 80, 99, 3, 5])
	assert_eq(s.deck.size(), 10)
	assert_eq(s.relics.map(func(r: RelicSlot) -> StringName: return r.data.id), [&"burning_blood"])
	assert_eq(s.potions.slots.size(), 3)
	assert_eq(s.potions.count(), 0)
	assert_eq(s.phase, RunPhase.Id.MAP)
	assert_eq(s.node_id, -1)
	assert_not_null(s.map)
	assert_eq(run.choices(), s.map.start_nodes())
	assert_eq(_checkpoints, [RunController.CP_RETURNED_TO_MAP])
	assert_eq(_phases, [RunPhase.Id.MAP])


func test_enter_node_only_reachable() -> void:
	var run := _run()
	var far := run.state.map.boss_id
	assert_false(run.enter_node(far))
	assert_false(run.enter_node(9999))
	assert_eq(run.state.phase, RunPhase.Id.MAP)


# —— 戦闘 ——

func test_combat_checkpoint_before_the_first_draw() -> void:
	var run := _run()
	var hand_at_checkpoint := [-1]
	# run を捕まえるラムダを run の signal につなぐと循環参照になるので、最後に外す。
	var probe := func(_r: StringName) -> void:
		hand_at_checkpoint[0] = run.combat.combat.piles.hand.size() if run.combat != null else -1
	run.checkpoint_reached.connect(probe)
	var started: Array[CombatController] = []
	run.combat_started.connect(func(c: CombatController) -> void:
		started.append(c)
		assert_eq(c.combat.events.size(), 0, "combat_started comes before the combat starts"))
	_checkpoints.clear()
	assert_true(run.enter_node(run.choices()[0].id))
	assert_eq(_checkpoints, [RunController.CP_COMBAT_STARTED], "no node_entered for combat nodes")
	assert_eq(hand_at_checkpoint[0], -1, "the checkpoint comes before the combat exists")
	assert_eq(run.state.phase, RunPhase.Id.COMBAT)
	assert_eq(started.size(), 1)
	assert_eq(run.combat.combat.piles.hand.size(), 5)
	assert_eq(run.state.active_encounter, run.state.current_node().encounter)
	assert_false(run.acknowledge_combat_end(), "not over yet")
	run.checkpoint_reached.disconnect(probe)


func test_victory_gives_reward_then_map() -> void:
	var run := _run()
	run.enter_node(run.choices()[0].id)
	run.state.hp = 50
	run.combat.combat.player.hp = 50
	RunFixtures.win_combat(run)
	_checkpoints.clear()
	assert_true(run.acknowledge_combat_end())
	assert_eq(run.state.hp, 56, "burning blood heals 6 and HP is written back")
	assert_eq(run.state.battles_won, 1)
	assert_eq(run.state.active_encounter, &"")
	assert_eq(run.state.phase, RunPhase.Id.REWARD)
	assert_eq(_checkpoints, [RunController.CP_REWARD_GENERATED])
	var reward := run.state.pending_reward
	assert_eq(reward.items[0].kind, RewardItem.Kind.GOLD)
	var gold := run.state.gold
	assert_true(run.take_reward(0))
	assert_eq(run.state.gold, gold + reward.items[0].gold)
	assert_false(run.take_reward(0), "a row is taken once")
	assert_false(run.take_reward(1), "a card row needs a card index")
	assert_true(run.take_reward(1, 2))
	assert_eq(run.state.deck.cards[-1].data, reward.items[1].cards[2])
	assert_true(run.leave_node())
	assert_eq(run.state.phase, RunPhase.Id.MAP)
	assert_null(run.state.pending_reward)
	assert_eq(_checkpoints[-1], RunController.CP_RETURNED_TO_MAP)
	assert_eq(run.choices(), run.state.map.choices_from(run.state.node_id))


func test_potion_reward_when_belt_is_full() -> void:
	var run := _run()
	var potion := _lib.potion(&"fire")
	for i in 3:
		run.state.potions.add(potion)
	run.state.phase = RunPhase.Id.REWARD
	run.state.pending_reward = Reward.new()
	run.state.pending_reward.add(RewardItem.of_potion(_lib.potion(&"block")))
	assert_false(run.take_reward(0), "the belt is full")
	assert_true(run.discard_potion(1))
	assert_true(run.take_reward(0))
	assert_eq(run.state.potions.slots[1].id, &"block")


func test_defeat() -> void:
	var run := _run()
	run.enter_node(run.choices()[0].id)
	RunFixtures.lose_combat(run)
	assert_true(run.acknowledge_combat_end())
	assert_eq(run.state.phase, RunPhase.Id.DEFEAT)
	assert_true(run.is_over())
	assert_null(run.combat)


func test_combat_result_is_written_back() -> void:
	var run := _run()
	run.state.add_relic(_lib.relic(&"toolbox"))
	run.state.potions.add(_lib.potion(&"healing"))
	run.enter_node(run.choices()[0].id)
	assert_true(run.combat.use_potion(0).ok)
	RunFixtures.win_combat(run)
	var gold := run.state.gold
	run.acknowledge_combat_end()
	assert_eq(run.state.potions.count(), 0, "a used potion is gone")
	assert_eq(run.state.gold, gold + 12, "toolbox gold")


# —— 戦闘以外のノード ——

func test_shop() -> void:
	var run := _run()
	var id := RunFixtures.force_next(run, MapNode.Type.SHOP)
	_checkpoints.clear()
	var shop_at_checkpoint := [true]
	var probe := func(_r: StringName) -> void: shop_at_checkpoint[0] = run.state.shop != null
	run.checkpoint_reached.connect(probe)
	assert_true(run.enter_node(id))
	run.checkpoint_reached.disconnect(probe)
	assert_eq(_checkpoints, [RunController.CP_NODE_ENTERED])
	assert_false(shop_at_checkpoint[0], "node_entered comes before the stock is generated")
	assert_eq(run.state.phase, RunPhase.Id.SHOP)
	var stock := run.state.shop
	assert_eq(stock.items.size(), 10)
	run.state.gold = 1000
	var card_index := 0
	var relic_index := stock.items.find(stock.of_kind(ShopItem.Kind.RELIC)[0])
	var potion_index := stock.items.find(stock.of_kind(ShopItem.Kind.POTION)[0])
	assert_true(run.buy(card_index))
	assert_eq(run.state.gold, 1000 - stock.items[0].price)
	assert_eq(run.state.deck.cards[-1].data, stock.items[0].card)
	assert_false(run.buy(card_index), "sold out")
	assert_true(run.buy(relic_index))
	assert_true(run.state.has_relic(stock.items[relic_index].relic))
	for i in 3:
		run.state.potions.add(_lib.potion(&"fire"))
	assert_false(run.can_buy(potion_index), "the belt is full")
	assert_false(run.buy(potion_index))
	run.discard_potion(0)
	assert_true(run.buy(potion_index))
	run.state.gold = 0
	assert_false(run.buy(1), "not enough gold")
	assert_true(run.leave_node())
	assert_null(run.state.shop)


func test_shop_services_are_unlimited_and_get_pricier() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.SHOP))
	run.state.gold = 1000
	var deck := run.state.deck
	assert_eq(run.removal_price(), 75)
	assert_true(run.buy_removal(deck.cards[0]))
	assert_eq(run.removal_price(), 100)
	assert_true(run.buy_removal(deck.cards[0]))
	assert_eq(run.state.gold, 1000 - 75 - 100)
	assert_eq(deck.size(), 8)
	assert_eq(run.upgrade_price(), 100)
	var card := deck.cards[0]
	assert_true(run.buy_upgrade(card))
	assert_true(String(card.data.id).ends_with("_plus"))
	assert_false(run.buy_upgrade(card), "already upgraded")
	assert_eq(run.upgrade_price(), 125)
	run.state.gold = 10
	assert_false(run.buy_removal(deck.cards[0]))


func test_rest() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.REST))
	assert_eq(run.state.phase, RunPhase.Id.REST)
	assert_false(run.leave_node(), "must rest or smith first")
	run.state.hp = 20
	assert_true(run.rest_heal())
	assert_eq(run.state.hp, 44, "30% of 80")
	assert_false(run.rest_upgrade(run.state.deck.cards[0]), "only one of the two")
	assert_false(run.rest_heal())
	assert_true(run.leave_node())


func test_rest_upgrade() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.REST))
	var card := run.state.deck.cards[9]
	assert_true(run.can_rest_upgrade())
	assert_true(run.rest_upgrade(card))
	assert_eq(card.data.id, &"bash_plus")
	assert_true(run.leave_node())


func test_rest_upgrade_unavailable_when_nothing_upgradable() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.REST))
	for c in run.state.deck.cards:
		c.upgrade()
	assert_false(run.can_rest_upgrade())
	assert_true(run.rest_heal())


func test_treasure() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.TREASURE))
	assert_eq(run.state.phase, RunPhase.Id.TREASURE)
	var items := run.state.pending_reward.items
	assert_eq(items.map(func(i: RewardItem) -> int: return i.kind), [RewardItem.Kind.GOLD, RewardItem.Kind.RELIC])
	assert_true(run.take_reward(1))
	assert_true(run.state.has_relic(items[1].relic))
	assert_true(run.leave_node(), "leaving without taking everything is allowed")
	assert_eq(run.state.phase, RunPhase.Id.MAP)


# —— イベント ——

func test_event_with_card_choice_requests() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.EVENT, &"wandering_smith"))
	assert_eq(run.state.phase, RunPhase.Id.EVENT)
	assert_eq(run.state.event.id, &"wandering_smith")
	run.state.gold = 40
	assert_false(run.event_option_available(0), "not enough gold")
	assert_null(run.choose_event_option(0))
	run.state.gold = 200
	var outcome := run.choose_event_option(1)
	assert_not_null(outcome)
	assert_eq(outcome.request_count, 1)
	assert_eq(run.state.gold, 125)
	assert_null(run.choose_event_option(2), "only one choice per event")
	assert_false(run.leave_node(), "requests must be resolved first")
	var req := run.pending_request()
	assert_eq(req.kind, RunChoiceRequest.Kind.REMOVE)
	assert_eq(run.request_candidates().size(), 10)
	assert_eq(run.request_pick_count(), 1)
	assert_false(run.resolve_request(PackedInt32Array([])), "must pick exactly one")
	assert_false(run.resolve_request(PackedInt32Array([10])), "out of range")
	var removed: Card = run.request_candidates()[3]
	assert_true(run.resolve_request(PackedInt32Array([3])))
	assert_false(run.state.deck.has(removed))
	assert_null(run.pending_request())
	assert_true(run.leave_node())
	assert_eq(run.state.phase, RunPhase.Id.MAP)


func test_event_pick_request() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.EVENT, &"whispering_idol"))
	var outcome := run.choose_event_option(0)
	assert_eq(outcome.request_count, 1)
	assert_eq(run.state.deck.cards[-1].data.id, &"injury", "the curse is added right away")
	var offers: Array = run.request_candidates()
	assert_eq(offers.size(), 3)
	assert_true(run.resolve_request(PackedInt32Array([2])))
	assert_eq(run.state.deck.cards[-1].data, offers[2])
	assert_eq(run.state.deck.size(), 12)


func test_event_queued_battle() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.EVENT, &"sleeping_guardian"))
	var relics := run.state.relics.size()
	var outcome := run.choose_event_option(1)
	assert_true(outcome.battle_queued)
	assert_eq(run.state.relics.size(), relics + 1)
	_checkpoints.clear()
	assert_true(run.leave_node())
	assert_eq(run.state.phase, RunPhase.Id.COMBAT, "the queued battle starts when leaving")
	assert_eq(_checkpoints, [RunController.CP_COMBAT_STARTED])
	assert_eq(run.state.queued_encounter, &"")
	assert_eq(_lib.encounter(run.state.active_encounter).rank, EnemyData.Rank.NORMAL)
	RunFixtures.win_combat(run)
	run.acknowledge_combat_end()
	assert_eq(run.state.phase, RunPhase.Id.REWARD, "the event battle gives rewards")
	run.leave_node()
	assert_eq(run.state.phase, RunPhase.Id.MAP)


func test_event_battle_without_rewards_returns_to_map() -> void:
	var run := _run()
	run.enter_node(RunFixtures.force_next(run, MapNode.Type.EVENT, &"abandoned_camp"))
	run.choose_event_option(0)
	run.state.queued_encounter = &"slime"
	run.state.queued_encounter_rewards = false
	run.leave_node()
	RunFixtures.win_combat(run)
	run.acknowledge_combat_end()
	assert_eq(run.state.phase, RunPhase.Id.MAP)


# —— アクト ——

func test_act_transition_and_final_victory() -> void:
	var lib := RunFixtures.short_library(_lib, 2)
	var run := _run(lib)
	_go_to_boss(run)
	assert_eq(run.state.phase, RunPhase.Id.COMBAT)
	RunFixtures.win_combat(run)
	run.acknowledge_combat_end()
	assert_eq(run.state.phase, RunPhase.Id.REWARD, "a non-final boss gives rewards")
	var relic_rows := run.state.pending_reward.items.filter(func(i: RewardItem) -> bool: return i.kind == RewardItem.Kind.RELIC)
	assert_eq((relic_rows[0] as RewardItem).relic.rarity, RelicData.Rarity.BOSS)
	_checkpoints.clear()
	run.leave_node()
	assert_eq(run.state.phase, RunPhase.Id.ACT_TRANSITION)
	assert_eq(_checkpoints, [RunController.CP_RETURNED_TO_MAP])
	run.state.hp = 10
	var old_map := run.state.map
	assert_true(run.advance_act())
	assert_eq(run.state.act_index, 1)
	assert_eq(run.state.hp, 10 + 24, "30% of max HP")
	assert_ne(run.state.map, old_map)
	assert_eq(run.state.node_id, -1)
	assert_eq(run.state.visited.size(), 0)
	assert_eq(run.state.phase, RunPhase.Id.MAP)
	assert_true(run.is_last_act())
	_go_to_boss(run)
	RunFixtures.win_combat(run)
	run.acknowledge_combat_end()
	assert_eq(run.state.phase, RunPhase.Id.VICTORY, "the last boss ends the run without rewards")
	assert_null(run.state.pending_reward)


func test_single_act_boss_is_victory() -> void:
	var run := _run(RunFixtures.short_library(_lib, 1))
	_go_to_boss(run)
	RunFixtures.win_combat(run)
	run.acknowledge_combat_end()
	assert_eq(run.state.phase, RunPhase.Id.VICTORY)


func test_act_heal_is_at_least_one() -> void:
	var cfg := _lib.config.duplicate() as RunConfig
	cfg.start_max_hp = 2
	var run := _run(RunFixtures.short_library(_lib, 2), 1, cfg)
	run.state.phase = RunPhase.Id.ACT_TRANSITION
	run.state.hp = 1
	run.advance_act()
	assert_eq(run.state.hp, 2)


func test_abandon() -> void:
	var run := _run()
	run.abandon()
	assert_eq(run.state.phase, RunPhase.Id.DEFEAT)


func test_commands_rejected_in_wrong_phase() -> void:
	var run := _run()
	assert_false(run.leave_node())
	assert_false(run.take_reward(0))
	assert_false(run.buy(0))
	assert_false(run.rest_heal())
	assert_false(run.advance_act())
	assert_null(run.choose_event_option(0))
	assert_false(run.acknowledge_combat_end())


## マップを最短でボスまで進める（途中のノードは種類を書き換えて素通りする）。
func _go_to_boss(run: RunController) -> void:
	while run.state.phase == RunPhase.Id.MAP:
		var next := run.choices()[0]
		if next.type == MapNode.Type.BOSS:
			run.enter_node(next.id)
			return
		RunFixtures.force_next(run, MapNode.Type.TREASURE)
		run.enter_node(next.id)
		run.leave_node()

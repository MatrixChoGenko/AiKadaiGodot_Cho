extends GutTest
## RunSerializer / SaveMigrations（Architecture §12.2）。

var _lib: ContentLibrary


func before_all() -> void:
	_lib = OfficialSetup.library()


func _rich_run() -> RunController:
	var run := RunFixtures.new_run(_lib, 77)
	var s := run.state
	s.deck.cards[0].upgrade()
	s.add_relic(_lib.relic(&"meditation_beads")).counter = 2
	s.potions.add(_lib.potion(&"fire"))
	s.potions.slots[2] = _lib.potion(&"weak")
	s.gold = 321
	s.battles_won = 4
	s.removals_bought = 1
	s.upgrades_bought = 2
	s.queued_encounter = &"slime"
	s.queued_encounter_rewards = false
	s.node_id = run.choices()[0].id
	s.visited.append(s.node_id)
	s.phase = RunPhase.Id.REWARD
	s.pending_reward = RewardFactory.for_combat(run.loot(), EnemyData.Rank.ELITE, s.owned_relics())
	s.pending_reward.items[0].taken = true
	return run


func test_round_trip_through_json_is_identical() -> void:
	var run := _rich_run()
	var first := RunFixtures.dump(run.state)
	var loaded := RunFixtures.reload_state(run.state, _lib)
	assert_eq(RunFixtures.dump(loaded), first)


func test_round_trip_restores_objects() -> void:
	var run := _rich_run()
	var s := RunFixtures.reload_state(run.state, _lib)
	assert_eq(s.deck.cards[0].data.id, &"strike_plus", "upgraded cards keep the upgraded id")
	assert_eq(s.deck.cards.map(func(c: Card) -> int: return c.uid), run.state.deck.cards.map(func(c: Card) -> int: return c.uid))
	assert_eq(s.deck.next_uid, run.state.deck.next_uid)
	assert_eq(s.relics[1].data.id, &"meditation_beads")
	assert_eq(s.relics[1].counter, 2, "relic counters are saved")
	assert_eq(s.potions.slots.map(func(p: PotionData) -> Variant: return p.id if p != null else null), [&"fire", null, &"weak"])
	assert_eq(s.phase, RunPhase.Id.REWARD)
	assert_true(s.pending_reward.items[0].taken)
	assert_eq(s.pending_reward.items[1].cards, run.state.pending_reward.items[1].cards)
	assert_eq(s.queued_encounter, &"slime")
	assert_false(s.queued_encounter_rewards)
	assert_eq(s.seed_value, 77)
	assert_eq(s.map.nodes.size(), run.state.map.nodes.size())
	assert_eq(s.map.boss().encounter, run.state.map.boss().encounter)


func test_rng_state_continues_exactly() -> void:
	var run := RunFixtures.new_run(_lib, 5)
	var s := RunFixtures.reload_state(run.state, _lib)
	for stream in RngStreams.STREAMS:
		assert_eq(s.rng.range_int(stream, 0, 1 << 30), run.state.rng.range_int(stream, 0, 1 << 30), String(stream))


func test_large_seed_survives_json() -> void:
	var run := RunFixtures.new_run(_lib, 9007199254740993)   # 2^53 + 1：double では表せない
	assert_eq(RunFixtures.reload_state(run.state, _lib).seed_value, 9007199254740993)


func test_unknown_ids_fail_without_crashing() -> void:
	var run := _rich_run()
	for broken: Array in [["deck", "card"], ["relics", "relic"], ["potions", "potion"], ["phase", "phase"]]:
		var d := RunSerializer.to_dict(run.state)
		match broken[0]:
			"deck":
				d["deck"]["cards"][0]["id"] = "no_such_card"
			"relics":
				d["relics"][0]["id"] = "no_such_relic"
			"potions":
				d["potions"][0] = "no_such_potion"
			"phase":
				d["phase"] = "NOPE"
		var s := RunSerializer.new()
		assert_null(s.from_dict(d, _lib), broken[0])
		assert_string_contains(s.error, broken[1])


func test_unsupported_versions() -> void:
	var d := RunSerializer.to_dict(RunFixtures.new_run(_lib).state)
	d["version"] = SaveMigrations.CURRENT_VERSION + 1
	var s := RunSerializer.new()
	assert_null(s.from_dict(d, _lib))
	assert_string_contains(s.error, "version")
	d.erase("version")
	assert_null(s.from_dict(d, _lib))


func test_migrations_run_in_order() -> void:
	var steps: Array[Callable] = [
		func(d: Dictionary) -> Dictionary:
			d["log"] = str(d.get("log", "")) + "1>2,"
			return d,
		func(d: Dictionary) -> Dictionary:
			d["log"] = str(d.get("log", "")) + "2>3"
			return d,
	]
	var out := SaveMigrations.migrate({version = 1}, steps, 3)
	assert_eq(out["version"], 3)
	assert_eq(out["log"], "1>2,2>3")
	assert_eq(SaveMigrations.migrate({version = 2}, steps, 3)["log"], "2>3")
	assert_eq(SaveMigrations.migrate({version = 3}, steps, 3), {version = 3}, "already current")
	assert_eq(SaveMigrations.migrate({version = 1}, [], 2), {}, "a missing step fails")
	assert_eq(SaveMigrations.migrate({version = 0}, steps, 3), {})

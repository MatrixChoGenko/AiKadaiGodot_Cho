extends GutTest
## MapGenerator：GameDesign §4.1 の生成ルール（付録 C の C30・C31・C33）を多数のシードで検査する。

const SEEDS: int = 60

var _lib: ContentLibrary
var _act: ActData


func before_all() -> void:
	_lib = OfficialSetup.library()
	_act = RunController.acts_of(_lib)[0]


func _gen(seed_value: int, act: ActData = _act, lib: ContentLibrary = _lib) -> MapGraph:
	return MapGenerator.generate(RngStreams.new(seed_value), act, lib, lib.config)


func test_same_seed_same_map() -> void:
	assert_eq(_describe(_gen(5)), _describe(_gen(5)))
	assert_ne(_describe(_gen(5)), _describe(_gen(6)))


func test_uses_only_map_encounter_event_streams() -> void:
	var rng := RngStreams.new(9)
	var before := rng.save()
	MapGenerator.generate(rng, _act, _lib, _lib.config)
	var after := rng.save()
	for s: String in before:
		if s in ["map", "encounter", "event"]:
			continue
		assert_eq(after[s], before[s], "stream %s was consumed" % s)


func test_shape_rules() -> void:
	for seed_value in SEEDS:
		var map := _gen(seed_value)
		var tag := "seed %d" % seed_value
		assert_eq(map.rows, _act.rows)
		assert_eq(map.boss().row, map.rows, tag)
		var starts := map.start_nodes()
		assert_gte(starts.size(), 2, "at least 2 distinct start nodes: " + tag)
		for n in map.nodes:
			assert_eq(map.nodes[n.id], n, "id == index")
			if n.type == MapNode.Type.BOSS:
				assert_eq(n.next.size(), 0)
				continue
			assert_gt(n.next.size(), 0, "dead end %s %s" % [n, tag])
			for id in n.next:
				var m := map.node(id)
				assert_eq(m.row, n.row + 1, "edges go to the next row: " + tag)
				if m.type != MapNode.Type.BOSS:
					assert_lte(absi(m.col - n.col), 1, "column step <= 1: " + tag)
			if n.row == map.rows - 1:
				assert_eq(Array(n.next), [map.boss_id], "last row connects to the boss: " + tag)
			# 全ノードは 0 行目から到達できる（パスが通ったマスだけがノード）。
			if n.row > 0:
				assert_gt(map.parents_of(n.id).size(), 0, "orphan %s %s" % [n, tag])


func test_paths_do_not_cross() -> void:
	for seed_value in SEEDS:
		var map := _gen(seed_value)
		var edges: Dictionary = {}
		for n in map.nodes:
			for id in n.next:
				edges["%d:%d:%d" % [n.row, n.col, map.node(id).col]] = true
		for n in map.nodes:
			if n.type == MapNode.Type.BOSS:
				continue
			for id in n.next:
				var m := map.node(id)
				if m.type == MapNode.Type.BOSS or m.col == n.col:
					continue
				assert_false(edges.has("%d:%d:%d" % [n.row, m.col, n.col]), "crossing at row %d cols %d/%d seed %d" % [n.row, n.col, m.col, seed_value])


func test_type_rules() -> void:
	var cfg := _lib.config
	for seed_value in SEEDS:
		var map := _gen(seed_value)
		var tag := "seed %d" % seed_value
		for n in map.nodes:
			if n.type == MapNode.Type.BOSS:
				continue
			if n.row == 0:
				assert_eq(n.type, MapNode.Type.BATTLE, "row 0 is battle: " + tag)
			elif n.row == map.rows - 1:
				assert_eq(n.type, MapNode.Type.REST, "row before boss is rest: " + tag)
			elif n.row == map.rows / 2:
				assert_eq(n.type, MapNode.Type.TREASURE, "middle row is treasure: " + tag)
			else:
				assert_ne(n.type, MapNode.Type.TREASURE, tag)
				if n.type in MapGenerator.SPECIAL_TYPES:
					var min_row := cfg.elite_min_row if n.type == MapNode.Type.ELITE else cfg.rest_shop_min_row
					assert_gte(n.row, min_row, "special before min row: %s %s" % [n, tag])
					for p in map.parents_of(n.id):
						assert_ne(p.type, n.type, "special same as parent: %s %s" % [n, tag])


func test_shop_guarantee() -> void:
	for seed_value in SEEDS:
		var map := _gen(seed_value)
		assert_gte(map.count_of(MapNode.Type.SHOP), _lib.config.min_shops, "seed %d" % seed_value)
		for s in map.start_nodes():
			var found := false
			for id in map.reachable_from(s.id):
				found = found or map.node(id).type == MapNode.Type.SHOP
			assert_true(found, "no shop route from %s seed %d" % [s, seed_value])


func test_contents_are_assigned_by_rank_and_act() -> void:
	var event_counts: Dictionary = {}
	for seed_value in SEEDS:
		var map := _gen(seed_value)
		for n in map.nodes:
			match n.type:
				MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.BOSS:
					var enc := _lib.encounter(n.encounter)
					assert_not_null(enc, "encounter for %s" % n)
					if enc != null:
						var expected := {MapNode.Type.BATTLE: EnemyData.Rank.NORMAL, MapNode.Type.ELITE: EnemyData.Rank.ELITE,
								MapNode.Type.BOSS: EnemyData.Rank.BOSS}
						assert_eq(enc.rank, expected[n.type], "rank of %s" % n)
					assert_eq(n.event, &"")
				MapNode.Type.EVENT:
					assert_not_null(_lib.event(n.event), "event for %s" % n)
					event_counts[n.event] = event_counts.get(n.event, 0) + 1
				_:
					assert_eq(n.encounter, &"")
					assert_eq(n.event, &"")
	assert_eq(event_counts.size(), _lib.events.size(), "all events appear across seeds")


func test_shuffle_bag_does_not_repeat_until_exhausted() -> void:
	for seed_value in 20:
		var map := _gen(seed_value)
		var seen: Array[StringName] = []
		for n in map.nodes:
			if n.type != MapNode.Type.EVENT:
				continue
			if seen.size() == _lib.events.size():
				seen.clear()   # バッグを詰め直した
			assert_false(seen.has(n.event), "event repeated before the bag was empty: seed %d" % seed_value)
			seen.append(n.event)


func test_empty_pools_downgrade_to_battle() -> void:
	var lib := ContentLibrary.new()
	lib.encounters = _lib.encounters.filter(func(e: EncounterData) -> bool: return e.rank != EnemyData.Rank.ELITE)
	lib.config = _lib.config
	for seed_value in 10:
		var map := _gen(seed_value, _act, lib)
		assert_eq(map.count_of(MapNode.Type.ELITE), 0)
		assert_eq(map.count_of(MapNode.Type.EVENT), 0)
		for n in map.nodes:
			if n.type == MapNode.Type.BATTLE:
				assert_ne(n.encounter, &"")


func test_early_rows_use_only_early_encounters() -> void:
	var cfg := _lib.config
	var late_seen := false
	for seed_value in SEEDS:
		var map := _gen(seed_value)
		for n in map.nodes:
			if n.type != MapNode.Type.BATTLE:
				continue
			var enc := _lib.encounter(n.encounter)
			if n.row < cfg.early_battle_rows:
				assert_true(enc.early, "non-early encounter %s on early row: %s seed %d" % [enc.id, n, seed_value])
			elif not enc.early:
				late_seen = true
	assert_true(late_seen, "non-early encounters still appear on later rows")


func test_early_rows_fall_back_to_all_normal_encounters() -> void:
	var lib := RunFixtures.multi_act_library(_lib, 1)
	for e in lib.encounters:
		e.early = false
	for seed_value in 10:
		var map := _gen(seed_value, lib.acts[0], lib)
		for n in map.start_nodes():
			assert_ne(n.encounter, &"")


func test_event_min_row_is_respected() -> void:
	var lib := RunFixtures.multi_act_library(_lib, 1)
	for e in lib.events:
		e.min_row = 9 if e.id == &"gambling_ghost" else 0
	for seed_value in 20:
		var map := _gen(seed_value, lib.acts[0], lib)
		for n in map.nodes:
			if n.event == &"gambling_ghost":
				assert_gte(n.row, 9)


func _describe(map: MapGraph) -> String:
	var parts := PackedStringArray()
	for n in map.nodes:
		parts.append("%d:%d,%d:%s:%s:%s%s" % [n.id, n.row, n.col, n.type, Array(n.next), n.encounter, n.event])
	return " ".join(parts)

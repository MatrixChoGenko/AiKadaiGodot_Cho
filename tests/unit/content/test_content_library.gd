extends GutTest
## M1 受け入れ：正式コンテンツの数が GameDesign 付録 A.3 と一致し、バリデータのエラーが 0、インデックスが最新であること。

const LIBRARY_PATH: String = "res://content/content_library.tres"

var _lib: ContentLibrary


func before_all() -> void:
	_lib = load(LIBRARY_PATH) as ContentLibrary


func test_library_loads() -> void:
	assert_not_null(_lib, "content_library.tres を読み込めない")


func test_counts_match_appendix_a3() -> void:
	assert_eq(_lib.cards.size(), 107, "cards")
	assert_eq(_lib.reward_pool().size(), 84, "reward pool")
	assert_eq(_lib.cards_by_rarity(CardData.Rarity.STARTER).size(), 3, "starter")
	assert_eq(_lib.cards_by_rarity(CardData.Rarity.COMMON).size(), 37, "common")
	assert_eq(_lib.cards_by_rarity(CardData.Rarity.UNCOMMON).size(), 35, "uncommon")
	assert_eq(_lib.cards_by_rarity(CardData.Rarity.RARE).size(), 12, "rare")
	assert_eq(_lib.cards_by_rarity(CardData.Rarity.SPECIAL).size(), 20, "special (14 upgrades + 6 status / curse)")
	assert_eq(_lib.statuses.size(), 10, "statuses")
	assert_eq(_lib.keywords.size(), 5, "keywords")
	assert_eq(_lib.relics.size(), 16, "relics")
	assert_eq(_lib.potions.size(), 10, "potions")
	assert_eq(_lib.enemies.size(), 6, "enemies")
	assert_eq(_lib.encounters.size(), 11, "encounters")
	assert_eq(_count_encounters(EnemyData.Rank.NORMAL), 7, "normal encounters")
	assert_eq(_count_encounters(EnemyData.Rank.ELITE), 3, "elite encounters")
	assert_eq(_count_encounters(EnemyData.Rank.BOSS), 1, "boss encounters")
	assert_eq(_lib.events.size(), 7, "events")
	assert_eq(_lib.acts.size(), 1, "acts")
	assert_not_null(_lib.config, "run config")


func test_validator_has_no_errors() -> void:
	var report := ContentValidator.new().validate(_lib)
	assert_eq(report.errors.size(), 0, str(report))


func test_index_is_up_to_date() -> void:
	# content/ を走査し直した結果と、保存されているインデックスが一致する（再構築忘れの検出）。
	var fresh := ContentIndexBuilder.collect()
	for field: String in ["cards", "statuses", "keywords", "relics", "potions", "enemies", "encounters", "events", "acts"]:
		assert_eq(_paths_of(_lib.get(field)), _paths_of(fresh.get(field)), "index out of date: %s" % field)
	assert_eq(_lib.config.resource_path, fresh.config.resource_path)


func test_starting_setup_matches_gdd() -> void:
	var cfg := _lib.config
	assert_eq(cfg.start_max_hp, 80)
	assert_eq(cfg.start_gold, 99)
	assert_eq(cfg.energy_per_turn, 3)
	assert_eq(cfg.draw_per_turn, 5)
	assert_eq(cfg.potion_slots, 3)
	var deck := cfg.starting_deck.map(func(c: CardData) -> StringName: return c.id)
	assert_eq(deck.count(&"strike"), 5)
	assert_eq(deck.count(&"defend"), 4)
	assert_eq(deck.count(&"bash"), 1)
	assert_eq(cfg.starting_relics.size(), 1)
	assert_eq(cfg.starting_relics[0].id, &"burning_blood")


func test_cards_reference_shared_content_not_copies() -> void:
	# 参照は別ファイル（ext_resource）であり、埋め込みのコピーではない。
	var bash := _lib.card(&"bash")
	assert_eq(bash.upgraded, _lib.card(&"bash_plus"))
	var apply := bash.on_play[1] as ApplyStatusEffect
	assert_eq(apply.status, _lib.status(&"vulnerable"))
	assert_eq(apply.target.resource_path, "res://content/presets/target_chosen.tres")


func test_upgrades_are_special_and_not_in_reward_pool() -> void:
	for c in _lib.cards:
		if c.upgraded != null:
			assert_eq(c.upgraded.rarity, CardData.Rarity.SPECIAL, "%s" % c.upgraded.id)
			assert_false(c.upgraded in _lib.reward_pool(), "%s" % c.upgraded.id)


func test_same_name_cards_were_renamed() -> void:
	var names: Dictionary = {}
	for c in _lib.cards:
		assert_false(names.has(c.name), "duplicate card name %s (%s / %s)" % [c.name, names.get(c.name), c.id])
		names[c.name] = c.id


func test_inspector_hides_cost_for_x_and_unplayable() -> void:
	var c := CardData.new()
	assert_true(_editor_visible(c, "cost"))
	c.cost_mode = CardData.CostMode.X
	assert_false(_editor_visible(c, "cost"))
	c.cost_mode = CardData.CostMode.UNPLAYABLE
	assert_false(_editor_visible(c, "cost"))


func _editor_visible(obj: Object, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if p["name"] == prop_name:
			return p["usage"] & PROPERTY_USAGE_EDITOR != 0
	return false


func _count_encounters(rank: EnemyData.Rank) -> int:
	return _lib.encounters.filter(func(e: EncounterData) -> bool: return e.rank == rank).size()


func _paths_of(arr: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for res: Resource in arr:
		out.append(res.resource_path)
	return out

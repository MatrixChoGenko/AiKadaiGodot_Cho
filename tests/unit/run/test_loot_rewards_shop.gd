extends GutTest
## LootTable / RewardFactory / ShopFactory（GameDesign §12.1〜§12.3、付録 C の C12・C29・C34・C40）。

var _lib: ContentLibrary
var _cfg: RunConfig


func before_all() -> void:
	_lib = OfficialSetup.library()
	_cfg = _lib.config


func _loot(seed_value: int = 1) -> LootTable:
	return LootTable.new(_lib, _cfg, RngStreams.new(seed_value))


func test_reward_rows_by_rank() -> void:
	var potions := {EnemyData.Rank.NORMAL: 0, EnemyData.Rank.ELITE: 0, EnemyData.Rank.BOSS: 0}
	for seed_value in 200:
		for rank: EnemyData.Rank in [EnemyData.Rank.NORMAL, EnemyData.Rank.ELITE, EnemyData.Rank.BOSS]:
			var r := RewardFactory.for_combat(_loot(seed_value), rank, [])
			var kinds := r.items.map(func(i: RewardItem) -> int: return i.kind)
			assert_eq(kinds[0], RewardItem.Kind.GOLD)
			assert_eq(kinds[1], RewardItem.Kind.CARDS)
			var gold := r.items[0].gold
			var gold_range: Vector2i = {EnemyData.Rank.NORMAL: _cfg.gold_normal, EnemyData.Rank.ELITE: _cfg.gold_elite,
					EnemyData.Rank.BOSS: _cfg.gold_boss}[rank]
			assert_between(gold, gold_range.x, gold_range.y)
			var cards := r.items[1].cards
			assert_eq(cards.size(), 3)
			assert_eq(_unique(cards.map(func(c: CardData) -> StringName: return c.id)), 3, "cards are distinct")
			for c in cards:
				assert_true(_lib.reward_pool().has(c), "only reward-pool cards")
			var relic_items := r.items.filter(func(i: RewardItem) -> bool: return i.kind == RewardItem.Kind.RELIC)
			match rank:
				EnemyData.Rank.NORMAL:
					assert_eq(relic_items.size(), 0)
				EnemyData.Rank.ELITE:
					assert_eq(relic_items.size(), 1)
					assert_true((relic_items[0] as RewardItem).relic.rarity in LootTable.RELIC_RARITIES)
				EnemyData.Rank.BOSS:
					assert_eq((relic_items[0] as RewardItem).relic.rarity, RelicData.Rarity.BOSS)
			if kinds.has(RewardItem.Kind.POTION):
				potions[rank] += 1
	assert_eq(potions[EnemyData.Rank.BOSS], 200, "boss always drops a potion")
	assert_between(potions[EnemyData.Rank.NORMAL], 50, 110, "about 40%")
	assert_between(potions[EnemyData.Rank.ELITE], 95, 145, "about 60%")


func test_rare_bonus_raises_rare_rate() -> void:
	var normal := 0
	var boss := 0
	for seed_value in 400:
		for c in _loot(seed_value).roll_cards(&"reward", 1, 0):
			normal += 1 if c.rarity == CardData.Rarity.RARE else 0
		for c in _loot(seed_value).roll_cards(&"reward", 1, _cfg.boss_rare_bonus):
			boss += 1 if c.rarity == CardData.Rarity.RARE else 0
	assert_between(normal, 15, 55, "8%")
	assert_between(boss, 65, 125, "28 / 120 = 23%")


func test_relic_exclusion_and_exhaustion() -> void:
	var loot := _loot()
	var owned: Array[RelicData] = []
	while true:
		var r := loot.roll_relic(&"reward", owned)
		if r == null:
			break
		assert_false(owned.has(r))
		owned.append(r)
	var expected := _lib.relics.filter(func(r: RelicData) -> bool: return r.rarity in LootTable.RELIC_RARITIES).size()
	assert_eq(owned.size(), expected, "every common/uncommon/rare relic is eventually drawn, then null")
	# ボスレリックを全部持っていたら通常の抽選へ（全部無ければ null）。
	var boss := loot.roll_boss_relic(&"reward", owned)
	assert_eq(boss.rarity, RelicData.Rarity.BOSS)


func test_treasure() -> void:
	for seed_value in 30:
		var r := RewardFactory.for_treasure(_loot(seed_value), [])
		assert_eq(r.items.size(), 2)
		assert_eq(r.items[0].kind, RewardItem.Kind.GOLD)
		assert_between(r.items[0].gold, _cfg.treasure_gold.x, _cfg.treasure_gold.y)
		assert_eq(r.items[1].kind, RewardItem.Kind.RELIC)


func test_reward_uses_only_reward_stream() -> void:
	var rng := RngStreams.new(4)
	var before := rng.save()
	RewardFactory.for_combat(LootTable.new(_lib, _cfg, rng), EnemyData.Rank.BOSS, [])
	var after := rng.save()
	for s: String in before:
		if s != "reward":
			assert_eq(after[s], before[s], "stream %s" % s)


func test_shop_stock() -> void:
	var toolbox := _lib.relic(&"toolbox")
	for seed_value in 100:
		var stock := ShopFactory.create(_loot(seed_value), [])
		var cards := stock.of_kind(ShopItem.Kind.CARD)
		var relics := stock.of_kind(ShopItem.Kind.RELIC)
		var potions := stock.of_kind(ShopItem.Kind.POTION)
		assert_eq([cards.size(), relics.size(), potions.size()], [5, 2, 3])
		assert_eq(_unique(cards.map(func(i: ShopItem) -> StringName: return i.card.id)), 5, "cards are distinct")
		for i in cards:
			var base := _cfg.card_prices[i.card.rarity]
			assert_between(i.price, roundi(base * 0.9), roundi(base * 1.1), "card price within ±10%")
		assert_ne(relics[0].relic, relics[1].relic)
		assert_true(relics[0].relic.rarity in LootTable.RELIC_RARITIES, "slot 1 is common/uncommon/rare")
		assert_eq(relics[1].relic, toolbox, "slot 2 is the shop relic")
		assert_eq(relics[1].price, 180, "toolbox has its own price")
		for i in potions:
			assert_eq(i.price, _cfg.potion_prices[i.potion.rarity])
	# ショップ専用レリックを持っていたら、2 枠目は通常の抽選になる。
	var stock := ShopFactory.create(_loot(1), [toolbox])
	var relics := stock.of_kind(ShopItem.Kind.RELIC)
	assert_eq(relics.size(), 2)
	assert_true(relics[1].relic.rarity in LootTable.RELIC_RARITIES)


func test_service_prices() -> void:
	assert_eq(ShopFactory.removal_price(_cfg, 0), 75)
	assert_eq(ShopFactory.removal_price(_cfg, 2), 125)
	assert_eq(ShopFactory.upgrade_price(_cfg, 0), 100)
	assert_eq(ShopFactory.upgrade_price(_cfg, 3), 175)


func _unique(list: Array) -> int:
	var d := {}
	for x: Variant in list:
		d[x] = true
	return d.size()

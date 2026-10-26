class_name OfficialSetup extends RefCounted
## テスト支援：正式コンテンツ（content_library.tres）で戦闘を作る。シミュレーションと正式カードのテストで使う。

const LIBRARY_PATH: String = "res://content/content_library.tres"


static func library() -> ContentLibrary:
	return load(LIBRARY_PATH) as ContentLibrary


## ランダムな構成の戦闘：エンカウント、初期デッキ + 報酬プールからランダムに extra_cards 枚、レリック 0〜3、ポーション。
static func random_combat(lib: ContentLibrary, seed_value: int, extra_cards: int = 10) -> CombatSetup:
	var pick := RandomNumberGenerator.new()
	pick.seed = seed_value
	var setup := CombatSetup.new()
	setup.config = lib.config
	setup.rng = RngStreams.new(seed_value)
	setup.encounter = lib.encounters[pick.randi_range(0, lib.encounters.size() - 1)]
	setup.player_hp = lib.config.start_max_hp
	setup.player_max_hp = lib.config.start_max_hp
	setup.energy_per_turn = lib.config.energy_per_turn
	setup.draw_per_turn = lib.config.draw_per_turn
	var uid := 1
	for data in lib.config.starting_deck:
		setup.deck.append(Card.new(uid, data))
		uid += 1
	var pool := lib.reward_pool()
	var specials := lib.cards_by_rarity(CardData.Rarity.SPECIAL)
	for i in extra_cards:
		# たまにアップグレード版やステータス / 呪いも混ぜて、全カードを通す。
		var data: CardData = pool[pick.randi_range(0, pool.size() - 1)] if pick.randi_range(0, 4) > 0 \
			else specials[pick.randi_range(0, specials.size() - 1)]
		setup.deck.append(Card.new(uid, data))
		uid += 1
	var relics := lib.relics.duplicate()
	for i in pick.randi_range(0, 3):
		var r: RelicData = relics.pop_at(pick.randi_range(0, relics.size() - 1))
		setup.relics.append(RelicSlot.new(r))
	for i in lib.config.potion_slots:
		setup.potions.append(lib.potions[pick.randi_range(0, lib.potions.size() - 1)] if pick.randi_range(0, 2) > 0 else null)
	return setup

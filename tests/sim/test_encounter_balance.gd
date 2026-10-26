extends GutTest
## バランス測定：初期デッキ・初期 HP で各エンカウントを GreedyBot に戦わせ、勝率と被ダメージの表を出す。
## 数値の調整（序盤のエンカウントの表など）の確認用。表は gut.p で出す（-Full で全ログを見る）。
## 戦闘の数（エンカウントごと）は環境変数 TRYCARD_BALANCE_COMBATS で変えられる（既定 200）。

const DEFAULT_COMBATS: int = 200


func test_starter_deck_against_every_encounter() -> void:
	var lib := OfficialSetup.library()
	var count := int(OS.get_environment("TRYCARD_BALANCE_COMBATS")) if OS.has_environment("TRYCARD_BALANCE_COMBATS") else DEFAULT_COMBATS
	var encounters := lib.encounters.duplicate()
	encounters.sort_custom(func(a: EncounterData, b: EncounterData) -> bool:
		return [a.rank, String(a.id)] < [b.rank, String(b.id)])
	var lines := PackedStringArray(["", "encounter           rank  win%  loss(avg)  loss(p90)  turns"])
	var hung := 0
	for enc: EncounterData in encounters:
		var wins := 0
		var turns := 0
		var losses: Array[int] = []
		for i in count:
			var ctl := CombatController.begin(_starter_setup(lib, enc, 5000 + i))
			if GreedyBot.new().play(ctl)["hung"]:
				hung += 1
			var r := ctl.result()
			turns += r.turns
			# 負けは最大 HP 分の被ダメとして数える。
			losses.append(lib.config.start_max_hp - (r.hp if r.victory else 0))
			if r.victory:
				wins += 1
		losses.sort()
		var total := 0
		for l in losses:
			total += l
		lines.append("%-19s %4d %5.0f %10.1f %10d %6.1f" % [enc.id, enc.rank, 100.0 * wins / count,
				float(total) / count, losses[int(count * 0.9)], float(turns) / count])
	gut.p("\n".join(lines))
	assert_eq(hung, 0, "hung combats")


func _starter_setup(lib: ContentLibrary, enc: EncounterData, seed_value: int) -> CombatSetup:
	var setup := CombatSetup.new()
	setup.config = lib.config
	setup.rng = RngStreams.new(seed_value)
	setup.encounter = enc
	setup.player_hp = lib.config.start_max_hp
	setup.player_max_hp = lib.config.start_max_hp
	setup.energy_per_turn = lib.config.energy_per_turn
	setup.draw_per_turn = lib.config.draw_per_turn
	var uid := 1
	for data in lib.config.starting_deck:
		setup.deck.append(Card.new(uid, data))
		uid += 1
	for r in lib.config.starting_relics:
		setup.relics.append(RelicSlot.new(r))
	return setup

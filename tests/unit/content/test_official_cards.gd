extends GutTest
## M2 受け入れ：正式なカードとポーションがすべてエラーなくプレイ / 使用できる。

var _lib: ContentLibrary


func before_all() -> void:
	_lib = OfficialSetup.library()


func _harness(hand: Array) -> CombatHarness:
	var defend := _lib.card(&"defend")
	var strike := _lib.card(&"strike")
	return CombatBuilder.new() \
		.with_hand(hand + [defend, strike, defend]) \
		.with_draw_pile([strike, defend, strike, defend, strike]) \
		.with_enemy(_lib.enemy(&"jawworm"), 400).with_enemy(_lib.enemy(&"slime"), 400) \
		.with_energy(10).with_config(_lib.config).interactive(false).build()


func test_every_card_plays() -> void:
	var played := 0
	for data in _lib.cards:
		var h := _harness([data])
		var card := h.card(data.id)
		assert_not_null(card, "%s should be in hand" % data.id)
		if data.cost_mode == CardData.CostMode.UNPLAYABLE:
			assert_eq(h.ctl.check_card(card).reason, PlayResult.UNPLAYABLE, String(data.id))
		else:
			var target := h.enemy(0) if h.ctl.needs_target(card) else null
			var r := h.ctl.play_card(card, target)
			assert_true(r.ok, "%s: %s" % [data.id, r.reason])
			played += 1
		# ターン終了時のトリガー（手札にある時 / 捨てられた時）と敵のターンも通す。
		assert_true(h.end_turn(), String(data.id))
		assert_true(h.cards_conserved(), "card conservation broken by %s" % data.id)
	gut.p("played %d cards" % played)


func test_every_potion_uses() -> void:
	for potion in _lib.potions:
		var h := CombatBuilder.new().with_hand([_lib.card(&"strike"), _lib.card(&"defend")]) \
			.with_enemy(_lib.enemy(&"jawworm"), 400).with_config(_lib.config).with_potions([potion]).interactive(false).build()
		var target := h.enemy(0) if potion.aim == CardData.Aim.ENEMY else null
		var r := h.ctl.use_potion(0, target)
		assert_true(r.ok, "%s: %s" % [potion.id, r.reason])
		assert_null(h.combat.potions[0])


func test_every_card_has_rendered_text_without_placeholders() -> void:
	var names := CardText.keyword_names_of(_lib.keywords)
	for data in _lib.cards:
		var outside := CardText.render(data, null, null, null, names)
		assert_false("{" in outside, "%s outside combat: %s" % [data.id, outside])
		var h := _harness([data])
		var inside := h.ctl.card_text(h.card(data.id), h.enemy(0), names)
		assert_false("{" in inside, "%s in combat: %s" % [data.id, inside])

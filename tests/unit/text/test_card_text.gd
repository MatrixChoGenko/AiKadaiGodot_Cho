extends GutTest
## CardText（動的テキスト）と KeywordScan。

const T = preload("res://tests/support/builders/content_kit.gd")


func test_text_shows_modified_value_with_color() -> void:
	var strike := T.strike(6)
	strike.text = "{damage} ダメージを与える。"
	var h := CombatBuilder.new().with_hand([strike]).build()
	var card := h.card(&"strike")
	assert_eq(h.ctl.card_text(card), "6 ダメージを与える。")
	h.add_status(h.player(), &"strength", 2)
	assert_eq(h.ctl.card_text(card), "[color=%s]8[/color] ダメージを与える。" % CardText.COLOR_UP)
	h.add_status(h.player(), &"weak", 1)
	assert_eq(h.ctl.card_text(card), "6 ダメージを与える。", "(6+2)×0.75 = 6")
	h.add_status(h.player(), &"strength", -2)   # スタックは 0 未満にならないので筋力が消える
	assert_eq(h.ctl.card_text(card), "[color=%s]4[/color] ダメージを与える。" % CardText.COLOR_DOWN, "6 × 0.75")


func test_text_outside_combat_uses_base_and_keywords() -> void:
	var c := T.card(&"opening", 0, [T.draw(2)], {kw = CardData.Keyword.INNATE | CardData.Keyword.EXHAUST})
	c.text = "2 枚引く。"
	var names := {KeywordData.Kind.INNATE: "天賦", KeywordData.Kind.EXHAUST: "廃棄"}
	assert_eq(CardText.render(c, null, null, null, names), "天賦。\n2 枚引く。\n廃棄。")


func test_text_preview_does_not_touch_rng() -> void:
	var dance := T.card(&"dance", 0, [T.repeat(2, [T.dmg(4, T.random_enemy())])])
	dance.text = "{damage}"
	var h := CombatBuilder.new().with_hand([dance]).with_enemy(T.dummy()).with_enemy(T.dummy()).build()
	var before := h.combat.rng.save()
	h.ctl.card_text(h.card(&"dance"))
	assert_eq(h.combat.rng.save(), before)


func test_keyword_scan_finds_nested_statuses() -> void:
	var stacks := StatusStacksValue.new()
	stacks.status = T.status(&"strength")
	var c := T.card(&"x", 0, [T.repeat(2, [T.apply(&"poison", 1), T.dmg(T.scaled(1, 1, stacks))])],
		{kw = CardData.Keyword.RETAIN})
	var scan := KeywordScan.of_card(c)
	assert_true(scan.statuses.has(T.status(&"poison")))
	assert_true(scan.statuses.has(T.status(&"strength")))
	assert_eq(scan.keywords, KeywordData.Kind.RETAIN)

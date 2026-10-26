extends GutTest
## M4：表現層の部品（手札の配置、カード面、カード一覧パネル、ポーション枠、Fx）。

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/widgets/card_view.tscn")
const LIST_SCENE: PackedScene = preload("res://scenes/widgets/card_list_modal.tscn")


func test_hand_layout_is_symmetric_and_fits() -> void:
	for n in range(1, 11):
		var first := HandLayout.compute(0, n)
		var last := HandLayout.compute(n - 1, n)
		assert_almost_eq(first.x, -last.x, 0.001, "symmetric x (n=%d)" % n)
		assert_almost_eq(first.z, -last.z, 0.001, "symmetric angle (n=%d)" % n)
		assert_lte(last.x - first.x, HandLayout.MAX_WIDTH + 0.001, "fits (n=%d)" % n)
		var mid := HandLayout.compute(int((n - 1) / 2.0), n)
		assert_lte(mid.y, first.y + 0.001, "edges sink (n=%d)" % n)
	assert_eq(HandLayout.compute(0, 1), Vector3.ZERO)


func test_card_view_shows_name_cost_and_text() -> void:
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(view)
	var bash := Content.library.card(&"bash")
	view.show_card(bash, UiText.card_text(bash))
	assert_eq((view.get_node("%NameLabel") as Label).text, bash.name)
	assert_eq((view.get_node("%Cost") as GlyphBadge).text, "2")
	assert_string_contains((view.get_node("%Desc") as RichTextLabel).text, "8")
	assert_eq((view.get_node("%Frame") as TextureRect).texture, UiGlyphs.RARITY_FRAMES[bash.rarity])
	assert_eq((view.get_node("%TypeLeft") as GlyphBadge).text, UiGlyphs.CARD_TYPE_GLYPHS[bash.type])
	view.update_text("x", 1)
	assert_eq((view.get_node("%Cost") as GlyphBadge).text_color, CardView.COST_DOWN_COLOR, "cheaper than base is green")


func test_card_view_frame_follows_rarity() -> void:
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(view)
	var frames := {}
	for rarity: CardData.Rarity in [CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON, CardData.Rarity.RARE]:
		var card := CardData.new()
		card.name = "x"
		card.rarity = rarity
		view.show_card(card, "")
		frames[(view.get_node("%Frame") as TextureRect).texture] = true
	assert_eq(frames.size(), 3, "bronze / silver / gold")
	var uncommon: CardData
	for c in Content.library.cards:
		if c.rarity == CardData.Rarity.UNCOMMON and c.upgraded != null:
			uncommon = c
	view.show_card(uncommon.upgraded, "")
	assert_eq((view.get_node("%Frame") as TextureRect).texture, UiGlyphs.RARITY_FRAMES[CardData.Rarity.UNCOMMON],
		"an upgraded card keeps the frame of its base card")


## きらめきとコストの丸はフレームのレアリティに従う：銅 = きらめきなし、銀 = 2〜3、金 = 4（王冠あり）。
func test_card_view_sparkle_and_cost_orb_follow_rarity() -> void:
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(view)
	var expect := {CardData.Rarity.COMMON: [0, 0], CardData.Rarity.UNCOMMON: [2, 3], CardData.Rarity.RARE: [4, 4]}
	for rarity: CardData.Rarity in expect:
		var card := CardData.new()
		card.id = &"sparkle_test"
		card.name = "x"
		card.rarity = rarity
		view.show_card(card, "")
		var n := view.sparkle_count()
		assert_between(n, int(expect[rarity][0]), int(expect[rarity][1]), "sparkles for rarity %d" % rarity)
		assert_eq((view.get_node("%CostOrb") as TextureRect).texture, UiGlyphs.RARITY_COST_ORBS[rarity])
	var mat := (view.get_node("%Sparkle") as TextureRect).material as ShaderMaterial
	assert_true(mat.get_shader_parameter(&"has_crown"), "gold frame has the crown")


## 輪郭グロー：使用可能 = 青白、選択中 = 金色（使用可能より優先）。型はフレームの画像。
func test_card_view_glow_follows_state() -> void:
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(view)
	var bash := Content.library.card(&"bash")
	view.show_card(bash, "")
	var mat := (view.get_node("%Glow") as ColorRect).material as ShaderMaterial
	assert_eq(mat.get_shader_parameter(&"frame_tex"), UiGlyphs.RARITY_FRAMES[bash.rarity])
	assert_false(view.is_glowing())
	view.set_playable(true)
	assert_true(view.is_glowing())
	assert_eq(mat.get_shader_parameter(&"glow_color"), CardView.GLOW_PLAYABLE)
	view.set_selected(true)
	assert_eq(mat.get_shader_parameter(&"glow_color"), CardView.GLOW_SELECTED)
	view.set_playable(false)
	assert_true(view.is_glowing(), "selected glows even when not playable")
	view.set_selected(false)
	assert_false(view.is_glowing())
	var other := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(other)
	assert_ne(((other.get_node("%Glow") as ColorRect).material as ShaderMaterial), mat, "each card has its own material")


## スイープ光：SHINE_DELAY 秒待ってから流れ、待っている間に離れたら取り消す。流れ始めたら最後まで流す。
func test_card_view_shine_waits_and_cancels() -> void:
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(view)
	view.show_card(Content.library.card(&"bash"), "")
	view.play_shine(CardView.SHINE_DELAY)
	await wait_seconds(CardView.SHINE_DELAY * 0.5)
	view.cancel_pending_shine()
	await wait_seconds(CardView.SHINE_DELAY + 0.1)
	assert_false(view.is_shining(), "left before the delay -> cancelled")
	view.play_shine(CardView.SHINE_DELAY)
	await wait_seconds(CardView.SHINE_DELAY + 0.1)
	assert_true(view.is_shining(), "shines after the delay")
	view.cancel_pending_shine()
	assert_true(view.is_shining(), "a running shine is not cut")
	await wait_seconds(CardView.SHINE_TIME)
	assert_false(view.is_shining(), "hidden after one sweep")


## 説明は羊皮紙からはみ出さない（長い説明は字を小さくして収める）。
func test_every_card_text_fits_the_parchment() -> void:
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(view)
	var desc := view.get_node("%Desc") as RichTextLabel
	var shrunk := 0
	for card in Content.library.cards:
		for data: CardData in [card, card.upgraded]:
			if data == null:
				continue
			view.show_card(data, UiText.card_text(data))
			assert_lte(float(desc.get_content_height()), desc.size.y + 0.5, "%s fits" % data.id)
			assert_gt(view.desc_font_size(), CardView.DESC_MIN_FONT, "%s is readable" % data.id)
			if view.desc_font_size() < CardView.DESC_FONT:
				shrunk += 1
	gut.p("cards with a smaller description font: %d" % shrunk)


func test_card_text_out_of_combat_has_keywords() -> void:
	# 付録 C の C14：キーワードはカード面で自動的に付け足す。
	assert_string_contains(UiText.card_text(Content.library.card(&"opening")), "天賦")


func test_card_list_modal_pick_validation() -> void:
	var modal := LIST_SCENE.instantiate() as CardListModal
	add_child_autofree(modal)
	var picked: Array = []
	modal.picked.connect(func(ix: PackedInt32Array) -> void: picked.append(ix))
	var strike := Content.library.card(&"strike")
	modal.enter({title = "t", entries = CardListModal.entries_of_data([strike, strike, strike]), min_count = 2, max_count = 2})
	assert_eq(modal.card_count(), 3)
	assert_false(modal.choose(PackedInt32Array([0])), "too few")
	assert_false(modal.choose(PackedInt32Array([0, 0])), "duplicate")
	assert_false(modal.choose(PackedInt32Array([0, 5])), "out of range")
	assert_true(modal.choose(PackedInt32Array([2, 0])))
	assert_eq(picked, [PackedInt32Array([0, 2])])


func test_sorted_by_name_hides_draw_order() -> void:
	var lib := Content.library
	var cards: Array[Card] = [Card.new(1, lib.card(&"strike")), Card.new(2, lib.card(&"bash")), Card.new(3, lib.card(&"defend"))]
	var names: Array[String] = []
	for c in CardListModal.sorted_by_name(cards):
		names.append(c.data.name)
	var expected := names.duplicate()
	expected.sort()
	assert_eq(names, expected)


func test_potion_bar_shows_slots() -> void:
	var bar := PotionBar.new()
	add_child_autofree(bar)
	var chosen: Array = []
	bar.action_chosen.connect(func(s: int, a: StringName) -> void: chosen.append([s, a]))
	var slots: Array[PotionData] = [Content.library.potion(&"healing"), null, null]
	bar.show_potions(slots)
	assert_eq(bar.slot_count(), 3)
	bar.choose(0, PotionBar.ACTION_DISCARD)
	assert_eq(chosen, [[0, PotionBar.ACTION_DISCARD]])


## 画像（tools/icon_sheet.py）：全レリック・ポーション・ステータス・意図の種類に絵がある（新しく足したらシートに描き足す）。
func test_every_relic_potion_status_and_intent_has_an_icon() -> void:
	for r in Content.library.relics:
		assert_not_null(UiGlyphs.relic_icon(r), "relic %s" % r.id)
	for p in Content.library.potions:
		assert_not_null(UiGlyphs.potion_icon(p), "potion %s" % p.id)
	for s in Content.library.statuses:
		assert_not_null(UiGlyphs.status_icon(s), "status %s" % s.id)
	for kind: Intent.Kind in Intent.Kind.values():
		assert_true(UiGlyphs.INTENT_ICONS.has(kind), "intent %s" % Intent.Kind.keys()[kind])


func test_fx_floating_number_returns_to_pool() -> void:
	Fx.clear()
	var before := Fx.active_count()
	Fx.spawn(&"floating_number", Vector2(100, 100), {text = "12"})
	assert_eq(Fx.active_count(), before + 1)
	Fx.clear()
	assert_eq(Fx.active_count(), 0)


## カードを出したときの光：待ってから弾け、終わったらプールに戻る。色は芯（Flash）以外に付く。
func test_fx_card_burst_returns_to_pool() -> void:
	Fx.clear()
	var node := Fx.spawn(&"card_burst", Vector2(300, 300), {color = Color.RED, delay = 0.05}) as ParticleFx
	assert_not_null(node)
	assert_eq(Fx.active_count(), 1)
	assert_eq((node.get_node("Sparkles") as CanvasItem).modulate, Color.RED)
	assert_eq((node.get_node("Flash") as CanvasItem).modulate, Color.WHITE)
	for i in 120:
		if Fx.active_count() == 0:
			break
		await get_tree().process_frame
	assert_eq(Fx.active_count(), 0, "再生が終わったらプールに戻る")


## 勝利の紙吹雪：画面の下の両角から打ち上げる（global_pos は使わない）。
func test_fx_victory_places_cannons_at_screen_corners() -> void:
	Fx.clear()
	var node := Fx.spawn(&"victory", Vector2(500, 500)) as VictoryFx
	assert_not_null(node)
	var size := node.get_viewport_rect().size
	assert_eq((node.get_node("CannonLeft") as Node2D).global_position, Vector2(0, size.y))
	assert_eq((node.get_node("CannonRight") as Node2D).global_position, Vector2(size.x, size.y))
	Fx.clear()
	assert_eq(Fx.active_count(), 0)

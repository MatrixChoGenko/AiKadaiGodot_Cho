extends GutTest
## M5：ツールチップ（U11）、ショップ（U12）、イベント（U13）、休憩とアップグレードの比較（U14）、アクト移行とトップバーの HP（U15）。
## 画面はクリックと同じ経路（画面の公開メソッド / CardView.pressed / モーダルの公開メソッド）で操作する。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/widgets/card_view.tscn")
const MODAL_SCENE: PackedScene = preload("res://scenes/widgets/card_list_modal.tscn")
const TEST_SAVE: String = "user://test_saves/m5_screens_run.json"

var _main: Node
var _saved_path: String


func before_each() -> void:
	_saved_path = SaveManager.run_path
	SaveManager.run_path = TEST_SAVE
	SaveManager.delete_run()


func after_each() -> void:
	await wait_process_frames(2)
	SaveManager.detach()
	SaveManager.delete_run()
	SaveManager.run_path = _saved_path


func _start(seed_value: int = 11, lib: ContentLibrary = null, cfg: RunConfig = null) -> RunController:
	_main = MAIN_SCENE.instantiate()
	(_main.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
	_main.set(&"content_override", lib)
	_main.set(&"config_override", cfg)
	add_child_autofree(_main)
	_main.call(&"start_new_run", seed_value)
	return _main.get(&"run") as RunController


func _screen() -> Screen:
	return _main.call(&"current_screen") as Screen


func _modal() -> CardListModal:
	return (_main.get_node("%ModalHost") as ModalHost).top() as CardListModal


func _go(run: RunController, type: MapNode.Type, content_id: StringName = &"") -> Screen:
	var id := RunFixtures.force_next(run, type, content_id)
	assert_true((_screen() as MapScreen).choose_node(id))
	return _screen()


func _card(id: StringName) -> CardData:
	return Content.library.card(id)


# —— ツールチップ（U11）——

func test_card_terms_come_from_the_effect_tree() -> void:
	var names: Array = UiText.card_terms(_card(&"bash")).map(func(t: Array) -> String: return t[0])
	assert_has(names, Content.library.status(&"vulnerable").name, "bash applies vulnerable")
	var retain: Array = UiText.card_terms(_card(&"composure")).map(func(t: Array) -> String: return t[0])
	assert_has(retain, "保留", "composure has the retain keyword")
	assert_eq(UiText.card_terms(_card(&"strike")).size(), 0, "plain strike has no terms")
	for t: Array in UiText.card_terms(_card(&"bash")):
		assert_false((t[1] as String).contains("{stacks}"), "stacks placeholder is filled")


func test_card_view_shows_tips_on_hover_and_hides_them() -> void:
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(view)
	view.show_card(_card(&"bash"), UiText.card_text(_card(&"bash")))
	view.mouse_entered.emit()
	assert_true(view.tips_shown())
	var tips := view.get_children().filter(func(n: Node) -> bool: return n is CardTips)
	assert_eq(tips.size(), 1)
	assert_eq((tips[0] as CardTips).count(), UiText.card_terms(_card(&"bash")).size())
	assert_true((tips[0] as CardTips).layer >= 100, "tips are above every screen and modal")
	view.mouse_exited.emit()
	assert_false(view.tips_shown())
	view.tips_enabled = false
	view.mouse_entered.emit()
	assert_false(view.tips_shown(), "disabled tips stay hidden")


func test_card_without_terms_shows_no_tips() -> void:
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	add_child_autofree(view)
	view.show_card(_card(&"strike"), UiText.card_text(_card(&"strike")))
	view.mouse_entered.emit()
	assert_false(view.tips_shown())


func test_badge_uses_the_shared_tooltip_panel() -> void:
	var badge := GlyphBadge.new()
	add_child_autofree(badge)
	var panel := badge._make_custom_tooltip("見出し\n本文") as TooltipPanel
	assert_not_null(panel)
	assert_eq(panel.title(), "見出し")
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "tooltips never block clicks")
	panel.free()


func test_intent_text_describes_the_move() -> void:
	var intent := Intent.new()
	intent.kind = Intent.Kind.ATTACK
	intent.damage = 6
	intent.hits = 2
	var text := UiText.intent_text(intent, "連撃")
	assert_true(text.begins_with("連撃\n"))
	assert_string_contains(text, "6 ダメージ × 2 回（合計 12）")
	var buff := Intent.new()
	buff.kind = Intent.Kind.BUFF
	assert_string_contains(UiText.intent_text(buff, ""), "強化")


func test_potion_text_explains_its_status() -> void:
	var text := UiText.potion_text(Content.library.potion(&"weak"))
	assert_false(text.contains("{"), "values are filled: %s" % text)
	assert_string_contains(text, Content.library.status(&"weak").name + "[/color]：")


# —— アップグレードの比較（U14）——

func test_upgrade_preview_needs_confirmation() -> void:
	var cards: Array[Card] = [Card.new(1, _card(&"strike")), Card.new(2, _card(&"bash"))]
	var modal := MODAL_SCENE.instantiate() as CardListModal
	add_child_autofree(modal)
	var picked: Array = []
	modal.picked.connect(func(ix: PackedInt32Array) -> void: picked.append(ix))
	modal.enter({entries = CardListModal.entries_of_cards(cards), min_count = 1, max_count = 1, upgrade_preview = true})
	assert_true(modal.upgrade_preview)
	var grid := modal.get_node("%Grid")
	(grid.get_child(1) as CardView).pressed.emit(grid.get_child(1))
	assert_eq(modal.comparing, 1, "click opens the comparison")
	assert_true((modal.get_node("%Compare") as Control).visible)
	assert_false((modal.get_node("Margin") as Control).visible, "the list is hidden behind the comparison")
	assert_eq(picked.size(), 0, "nothing is decided yet")
	var after := modal.get_node("%AfterSlot").get_child(0) as CardView
	assert_eq(after.data, _card(&"bash").upgraded)
	modal.cancel()
	assert_eq(modal.comparing, -1, "Esc / back returns to the list")
	assert_false(modal.is_queued_for_deletion())
	modal.open_compare(0)
	modal.confirm_compare()
	assert_eq(picked, [PackedInt32Array([0])])


func test_non_cancellable_panel_can_still_leave_the_comparison() -> void:
	var modal := MODAL_SCENE.instantiate() as CardListModal
	add_child_autofree(modal)
	modal.enter({entries = CardListModal.entries_of_data([_card(&"strike")]), min_count = 1, max_count = 1,
			cancellable = false, upgrade_preview = true})
	modal.open_compare(0)
	modal.cancel()
	assert_eq(modal.comparing, -1)


# —— 休憩（U14）——

func test_rest_upgrade_goes_through_comparison() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.REST) as RestScreen
	screen.open_upgrade()
	assert_true(_modal().upgrade_preview)
	var target := run.state.deck.upgradable()[0]
	var before := target.data.name
	_modal().open_compare(0)
	assert_false(run.state.rest_used, "comparison alone does not upgrade")
	_modal().confirm_compare()
	assert_true(run.state.rest_used)
	assert_eq(target.data.name, before + "+")
	assert_string_contains(screen.desc_text(), before)
	assert_true(screen.tiles.is_empty(), "the tiles go away after choosing")
	assert_true(screen.proceed_button.visible, "the arrow leads on")
	screen.leave()
	assert_is(_screen(), MapScreen)


func test_rest_heal_shows_result() -> void:
	var run := _start()
	run.state.hp = 20
	var screen := _go(run, MapNode.Type.REST) as RestScreen
	var heal := screen.heal_amount()
	assert_eq(heal, int(run.state.max_hp * run.config.rest_heal_percent / 100.0))
	screen.rest()
	assert_eq(run.state.hp, 20 + heal)
	assert_string_contains(screen.desc_text(), "%d 回復" % heal)


# —— ショップ（U12）——

func test_shop_has_three_rows_and_every_item() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.SHOP) as ShopScreen
	var stock := run.state.shop
	assert_eq(screen.offer_views.size(), stock.items.size())
	for i in stock.items.size():
		var view := screen.offer_views[i]
		assert_true(view is CardView if stock.items[i].kind == ShopItem.Kind.CARD else view is GlyphBadge)
	assert_not_null(screen.removal_button)
	assert_not_null(screen.upgrade_button)


func test_shop_click_buys_and_marks_sold() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.SHOP) as ShopScreen
	run.state.gold = 999
	screen.rebuild()
	var card_index := -1
	for i in run.state.shop.items.size():
		if run.state.shop.items[i].kind == ShopItem.Kind.CARD:
			card_index = i
			break
	var price := run.state.shop.items[card_index].price
	var view := screen.offer_views[card_index] as CardView
	view.pressed.emit(view)
	assert_true(run.state.shop.items[card_index].sold)
	assert_eq(run.state.gold, 999 - price)
	assert_eq(screen.price_labels[card_index].text, "売り切れ")


func test_shop_short_gold_is_red_and_not_bought() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.SHOP) as ShopScreen
	run.state.gold = 0
	screen.rebuild()
	var label := screen.price_labels[0]
	assert_eq(label.get_theme_color(&"font_color"), ShopScreen.PRICE_SHORT_COLOR)
	screen.buy(0)
	assert_false(run.state.shop.items[0].sold)
	assert_true(_has_notice(screen, "ゴールドが足りません"))
	screen.open_removal()
	assert_null(_modal(), "removal needs gold")


func test_shop_potion_when_belt_is_full() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.SHOP) as ShopScreen
	run.state.gold = 999
	for i in run.state.potions.slots.size():
		run.state.potions.slots[i] = Content.library.potion(&"block")
	screen.rebuild()
	for i in run.state.shop.items.size():
		if run.state.shop.items[i].kind == ShopItem.Kind.POTION:
			screen.buy(i)
			assert_false(run.state.shop.items[i].sold)
			break
	assert_true(_has_notice(screen, "ポーション枠がいっぱい"))


func test_shop_upgrade_service_uses_comparison() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.SHOP) as ShopScreen
	run.state.gold = 999
	screen.rebuild()
	screen.open_upgrade()
	assert_true(_modal().upgrade_preview)
	_modal().open_compare(0)
	_modal().confirm_compare()
	assert_eq(run.state.upgrades_bought, 1)
	assert_string_contains(screen.upgrade_button.text, str(run.upgrade_price()))


func _has_notice(screen: PanelScreen, text: String) -> bool:
	for child in screen.body.get_children():
		if child is Label and (child as Label).text.contains(text):
			return true
	return false


# —— イベント（U13）——

func test_event_upgrade_request_uses_comparison() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.EVENT, &"wandering_smith") as EventScreen
	run.state.gold = 999
	screen.rebuild()
	screen.choose(0)
	assert_not_null(_modal())
	assert_true(_modal().upgrade_preview)
	assert_false(_modal().cancellable)
	_modal().open_compare(0)
	_modal().confirm_compare()
	assert_null(run.pending_request())
	assert_true(run.can_leave())


func test_event_disabled_option_shows_hint() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.EVENT, &"wandering_smith") as EventScreen
	run.state.gold = 0
	screen.rebuild()
	var first := screen.option_buttons[0]
	assert_true(first.disabled)
	assert_eq(first.title_text(), run.state.event.options[0].text)
	assert_string_contains(first.detail_text(), run.state.event.options[0].disabled_hint)
	assert_string_contains(first.detail_text(), run.state.event.options[0].detail)


func test_event_detail_markup_colors_gold_hp_and_curses() -> void:
	assert_eq(UiText.event_detail_markup("+35 ゴールド、HP +8"),
			"[color=#f0c75e]+35 ゴールド[/color]、[color=#8ee07a]HP +8[/color]")
	assert_eq(UiText.event_detail_markup("最大 HP +5"), "[color=#8ee07a]最大 HP +5[/color]")
	assert_eq(UiText.event_detail_markup("+120 ゴールド、呪い「疑念」を 2 枚得る"),
			"[color=#f0c75e]+120 ゴールド[/color]、[color=#ff7a6a]呪い「疑念」を 2 枚[/color]得る")
	assert_eq(UiText.event_detail_markup("レリックを 1 つ得て、戦闘に入る"), "レリックを 1 つ得て、戦闘に入る")


# —— アクト移行とトップバー（U15）——

func test_act_transition_heals_and_top_bar_animates() -> void:
	var lib := RunFixtures.short_library(Content.library, 2, 3)
	var run := _start(5, lib, RunFixtures.tough_config(Content.library.config))
	var bot := UiBot.new(_main, 5)
	for i in 20000:
		if _screen() is ActTransitionScreen:
			break
		assert_true(bot.step(), "bot reaches the act transition: %s" % bot.failure)
		await get_tree().process_frame
	var screen := _screen() as ActTransitionScreen
	assert_not_null(screen)
	run.state.hp = 100
	var top_bar := _main.get_node("%TopBarView") as TopBar
	top_bar.show_run(run)
	# HP 100 まで縮み切ってから回復させる（1 フレームの長さに依存しないように）。
	await wait_seconds(TopBar.HP_TWEEN_SECONDS + 0.1)
	var heal := screen.heal_amount()
	assert_eq(heal, int(run.state.max_hp * run.config.act_heal_percent / 100.0))
	screen.advance()
	assert_is(_screen(), MapScreen)
	assert_eq(run.state.hp, 100 + heal)
	assert_lt(top_bar.shown_hp, run.state.hp, "the HP bar grows over time, not at once")
	await wait_seconds(TopBar.HP_TWEEN_SECONDS + 0.2)
	assert_eq(top_bar.shown_hp, run.state.hp)
	assert_eq(top_bar.hp_text(), "%d/%d" % [run.state.hp, run.state.max_hp])


## 戦闘中もポーションはトップバーに出し、操作（使う）は戦闘画面へ渡る。戦闘の自前の枠は隠れる。
func test_combat_potions_live_in_the_top_bar() -> void:
	var run := _start(11)
	assert_true(run.state.potions.add(Content.library.potion(&"fire")))
	var screen := _go(run, MapNode.Type.BATTLE, &"jawworm") as CombatScreen
	screen.presenter.instant = true
	assert_true(await _until(screen.can_act))
	var bar := _main.get_node("%TopBarView").get_node("%Potions") as PotionBar
	assert_true(bar.is_visible_in_tree())
	assert_false((screen.get_node("%Potions") as Control).visible, "the combat screen's own slots are hidden")
	var enemy := screen.ctl.combat.enemies[0]
	var before := enemy.hp
	bar.choose(0, PotionBar.ACTION_USE)
	assert_eq(screen.hand_input.state, HandInput.State.POTION_AIM, "the fire potion asks for a target")
	screen.hand_input.cancel()
	assert_true(screen.try_use_potion(0, enemy))
	assert_true(await _until(screen.can_act))
	assert_lt(enemy.hp, before)
	assert_eq(screen.potion_origin(), bar.get_global_rect().get_center())
	RunFixtures.win_combat(run)
	assert_true(await _until(screen.result_pending))
	screen.continue_after_result()
	assert_is(_screen(), RewardScreen)
	var actions: Array = bar.actions_provider.call(0)
	assert_eq(actions.map(func(a: Array) -> StringName: return a[0]), [PotionBar.ACTION_DISCARD],
			"after the combat the bar is no longer lent")


func _until(cond: Callable, frames: int = 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()

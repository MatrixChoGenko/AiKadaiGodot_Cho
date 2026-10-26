extends GutTest
## M4：各画面の基本操作をクリックと同じ経路（画面の公開メソッド / モーダルの choose）で通す。
## ノードの種類は RunFixtures.force_next で書き換えて狙った画面に入る。セーブは user://test_saves/ に差し替える。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const SANDBOX_SCENE: PackedScene = preload("res://scenes/debug/combat_sandbox.tscn")
const TEST_SAVE: String = "user://test_saves/screens_run.json"

var _main: Node
var _saved_path: String


func before_each() -> void:
	_saved_path = SaveManager.run_path
	SaveManager.run_path = TEST_SAVE
	SaveManager.delete_run()


func after_each() -> void:
	await wait_process_frames(2)   # queue_free した画面とパネルの子を解放させる（GUT の Orphans 検出）
	SaveManager.detach()
	SaveManager.delete_run()
	SaveManager.run_path = _saved_path


func _start(seed_value: int = 11) -> RunController:
	_main = MAIN_SCENE.instantiate()
	(_main.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
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


## 条件が成り立つまでフレームを進める。
func _until(cond: Callable, frames: int = 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func test_map_screen_shows_choices() -> void:
	var run := _start()
	var screen := _screen() as MapScreen
	var view := screen.get_node("%MapView") as MapView
	for n in run.choices():
		assert_not_null(view.badge_of(n.id))
	assert_eq(view.get_child_count(), run.state.map.nodes.size())


func test_shop_buy_removal_and_leave() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.SHOP) as ShopScreen
	assert_not_null(screen)
	run.state.gold = 999
	screen.rebuild()
	var bought := -1
	for i in run.state.shop.items.size():
		if run.can_buy(i):
			bought = i
			break
	screen.buy(bought)
	assert_true(run.state.shop.item(bought).sold)
	var deck_size := run.state.deck.size()
	screen.open_removal()
	assert_not_null(_modal())
	assert_true(_modal().choose(PackedInt32Array([0])))
	assert_eq(run.state.deck.size(), deck_size - 1)
	assert_eq(run.state.removals_bought, 1)
	screen.leave()
	assert_is(_screen(), MapScreen)


func test_event_card_pick_request() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.EVENT, &"shrine_of_blood") as EventScreen
	var deck_size := run.state.deck.size()
	screen.choose(0)
	assert_not_null(_modal(), "PICK request opens the card panel")
	assert_false(_modal().cancellable)
	assert_true(_modal().choose(PackedInt32Array([1])))
	assert_eq(run.state.deck.size(), deck_size + 1)
	assert_null(run.pending_request())
	assert_true(run.can_leave())
	screen.leave()
	assert_is(_screen(), MapScreen)


func test_rest_upgrade() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.REST) as RestScreen
	screen.open_upgrade()
	var candidates := run.state.deck.upgradable()
	var target := candidates[0]
	assert_true(_modal().choose(PackedInt32Array([0])))
	assert_true(run.state.rest_used)
	assert_true(target.data.name.ends_with("+"), "upgraded: %s" % target.data.name)
	screen.leave()
	assert_is(_screen(), MapScreen)


func test_treasure_take_relic() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.TREASURE) as RewardScreen
	assert_not_null(screen.chest, "the treasure node shows the chest room")
	assert_false(screen.chest.is_open, "the chest starts closed")
	assert_false(screen.rows.values()[0].is_visible_in_tree(), "the loot waits for the chest")
	var lid := screen.chest.size / 2.0
	assert_true(screen.chest.is_over_chest(lid), "the middle of the screen is on the painted chest")
	assert_false(screen.chest.is_over_chest(Vector2(10, 10)))
	assert_false(screen.chest.shows_open_image())
	screen.chest.open(false)
	assert_true(screen.chest.shows_open_image(), "the painting switches to the open chest")
	assert_true(screen.rows.values()[0].is_visible_in_tree(), "opening shows the loot")
	var relics := run.state.relics.size()
	for i in run.state.pending_reward.items.size():
		screen.take(i)
	assert_eq(run.state.relics.size(), relics + 1)
	screen.leave()
	assert_is(_screen(), MapScreen)


## 条件が成り立つまで実時間で待つ（演出の Tween を待つとき。フレーム数だとヘッドレスでは一瞬で過ぎる）。
func _until_seconds(cond: Callable, seconds: float) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < limit:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func test_combat_turn_transition_banner_and_end_turn_button() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.BATTLE, &"jawworm") as CombatScreen
	var banner := screen.get_node("%Banner") as TurnBanner
	var button := screen.get_node("%EndTurnButton") as Button
	assert_true(await _until_seconds(screen.can_act, 10.0), "player turn becomes actionable")
	assert_true(banner.is_showing(), "あなたのターンのバナー")
	assert_true(await _until_seconds(func() -> bool: return button.visible and button.modulate.a > 0.99, 3.0),
			"ターン終了ボタンが下から出る")
	assert_eq(button.text, "ターン終了 1")
	await get_tree().create_timer(0.6).timeout
	var home_y := button.position.y
	screen.end_turn()
	assert_true(await _until_seconds(func() -> bool: return not screen.presenter.player_turn_shown, 2.0),
			"TURN_ENDING の再生で入力をロック")
	assert_true(banner.is_showing(), "敵のターンのバナー")
	assert_true(await _until_seconds(func() -> bool: return not button.visible, 2.0), "ボタンが引っ込む")
	assert_true(await _until_seconds(screen.can_act, 15.0), "next player turn")
	assert_eq(button.text, "ターン終了 2")
	# 回帰：position.y を動かすと offset_top も変わるので、定位置を offset_top から毎回計算すると 1 ターンごとに下へずれていった。
	assert_true(await _until_seconds(func() -> bool: return button.modulate.a > 0.99, 3.0), "2 ターン目もボタンが出る")
	await get_tree().create_timer(0.6).timeout
	assert_almost_eq(button.position.y, home_y, 0.5, "ボタンは毎ターン同じ位置に戻る")


func test_combat_screen_play_win_and_reward() -> void:
	var run := _start()
	var screen := _go(run, MapNode.Type.BATTLE, &"jawworm") as CombatScreen
	assert_not_null(screen)
	screen.presenter.instant = true
	assert_true(await _until(screen.can_act), "player turn becomes actionable")
	var c := screen.ctl.combat
	assert_eq(screen.hand.views().size(), c.piles.hand.size(), "hand view matches the model hand")
	var enemy := c.enemies[0]
	var ev := screen.unit_view(enemy.uid)
	assert_ne(ev.intent_text(), "", "jawworm opens with an attack intent")
	var attack: Card = null
	for card in c.piles.hand:
		if card.data.type == CardData.Type.ATTACK and screen.ctl.check_card(card, enemy).ok:
			attack = card
			break
	assert_not_null(attack)
	assert_true(screen.try_play(attack, enemy))
	assert_true(await _until(screen.can_act))
	assert_eq(ev.shown_hp, enemy.hp, "HP bar follows the damage event")
	assert_lt(enemy.hp, enemy.max_hp)
	assert_eq(screen.hand.views().size(), c.piles.hand.size())
	assert_eq((screen.get_node("%DiscardButton") as PileButton).count, c.piles.discard.size())
	screen.end_turn()
	assert_true(await _until(screen.can_act), "next player turn")
	assert_eq(c.turn.number, 2)
	RunFixtures.win_combat(run)
	assert_true(await _until(screen.result_pending), "victory is waiting to move on after the replay")
	assert_false((screen.get_node("%ResultPanel") as Control).visible, "a victory in a run shows no result panel")
	screen.continue_after_result()
	assert_is(_screen(), RewardScreen)
	var host := _main.get_node("Screens/ScreenHost") as ScreenHost
	assert_eq(host.backdrop, screen, "the battlefield stays behind the rewards")
	assert_eq(screen.hand.process_mode, Node.PROCESS_MODE_DISABLED, "the hand no longer runs")
	(_screen() as RewardScreen).leave()
	assert_is(_screen(), MapScreen)
	assert_null(host.backdrop, "the battlefield goes away with the rewards")


## 戦利品：カードの行 → 3 択（showcase）。スキップしても行は残り、選んだら行が消えてデッキに入る。ゴールドの行も消える。
func test_reward_rows_and_card_showcase() -> void:
	var run := _start()
	var combat := _go(run, MapNode.Type.BATTLE, &"jawworm") as CombatScreen
	combat.presenter.instant = true
	RunFixtures.win_combat(run)
	assert_true(await _until(combat.result_pending))
	combat.continue_after_result()
	var screen := _screen() as RewardScreen
	var items := run.state.pending_reward.items
	assert_eq(screen.rows.size(), items.size(), "one row per reward")
	var card_row := -1
	var gold_row := -1
	for i in items.size():
		if items[i].kind == RewardItem.Kind.CARDS:
			card_row = i
		elif items[i].kind == RewardItem.Kind.GOLD:
			gold_row = i
	assert_ne(card_row, -1, "a combat gives a card reward")
	assert_eq(screen.proceed_button.label_text(), "スキップ", "rewards are left")
	screen.take(card_row)
	var modal := _modal()
	assert_not_null(modal.showcase, "the card reward uses the showcase")
	assert_eq(modal.showcase.views.size(), items[card_row].cards.size())
	modal.showcase.show_upgraded(true)
	var upgraded := items[card_row].cards[0].upgraded
	if upgraded != null:
		assert_eq(modal.showcase.views[0].data, upgraded, "the eye shows the upgraded card")
	modal.cancel()
	assert_true(screen.rows.has(card_row), "skipping keeps the card row")
	var deck := run.state.deck.size()
	screen.take(card_row)
	assert_true(_modal().choose(PackedInt32Array([1])))
	assert_eq(run.state.deck.size(), deck + 1)
	assert_eq(run.state.deck.cards.back().data, items[card_row].cards[1], "the picked card, not its upgrade")
	assert_false(screen.rows.has(card_row), "the taken row goes away")
	if gold_row >= 0:
		var gold := run.state.gold
		screen.take(gold_row)
		assert_eq(run.state.gold, gold + items[gold_row].gold)
		assert_false(screen.rows.has(gold_row))
	if not screen.has_untaken():
		assert_eq(screen.proceed_button.label_text(), "進む")


func test_combat_card_choice_modal() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	var sift := Content.library.card(&"sift")
	var strike := Content.library.card(&"strike")
	# 山札の一番上 = 末尾。sift を初手に入れる。
	sandbox.set(&"deck", [strike, strike, strike, strike, strike, strike, strike, strike, strike, sift] as Array[CardData])
	sandbox.set(&"keep_deck_order", true)
	(sandbox.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
	add_child_autofree(sandbox)
	var host := sandbox.get_node("%ScreenHost") as ScreenHost
	var modals := sandbox.get_node("%ModalHost") as ModalHost
	var screen := host.current as CombatScreen
	screen.presenter.instant = true
	assert_true(await _until(screen.can_act))
	var card: Card = null
	for h in screen.ctl.combat.piles.hand:
		if h.data.id == &"sift":
			card = h
	assert_not_null(card)
	assert_true(screen.try_play(card, null))
	assert_true(await _until(func() -> bool: return not modals.is_empty()), "choice panel opens")
	var modal := modals.top() as CardListModal
	assert_false(modal.cancellable)
	assert_false(screen.can_act(), "input is locked while choosing")
	assert_true(modal.choose(PackedInt32Array([0])))
	assert_true(await _until(screen.can_act))
	assert_eq(screen.ctl.combat.piles.discard.size(), 2, "sift and the discarded card")
	assert_eq(screen.hand.views().size(), screen.ctl.combat.piles.hand.size())


func test_combat_potion_use() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	sandbox.set(&"potions", [Content.library.potion(&"fire")] as Array[PotionData])
	(sandbox.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
	add_child_autofree(sandbox)
	var screen := (sandbox.get_node("%ScreenHost") as ScreenHost).current as CombatScreen
	screen.presenter.instant = true
	assert_true(await _until(screen.can_act))
	var enemy := screen.ctl.combat.enemies[0]
	var before := enemy.hp
	var bar := screen.get_node("%Potions") as PotionBar
	assert_eq(bar.slot_count(), Content.library.config.potion_slots)
	assert_false(screen.try_use_potion(0, null), "fire potion needs a target")
	assert_true(screen.try_use_potion(0, enemy))
	assert_true(await _until(screen.can_act))
	assert_eq(enemy.hp, before - 20)
	assert_null(screen.ctl.combat.potions[0])

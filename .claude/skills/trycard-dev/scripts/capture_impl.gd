extends RefCounted
## 確認用：メニュー → マップ → 戦闘（ホバー＋用語の説明・照準・被弾・敵のターン・結果）→ 報酬 → カード選択
## → ショップ（購入後・カードのホバー）→ イベント（鍛冶屋 → アップグレードの比較）→ 休憩 → 休憩のアップグレードの比較を撮る。
## capture_screens.gd から load() される（-s のスクリプトから画面のクラスを静的に参照しないため）。

## 出力先（起動引数 `-- <dir>` で指定。省略時は user://shots/）。
var OUT: String = "user://shots/"

var main: Node


var tree: SceneTree
var root: Window


func start(p_tree: SceneTree) -> void:
	tree = p_tree
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		OUT = user_args[0].replace("\\", "/").trim_suffix("/") + "/"
	root = tree.root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _run()


func _wait(frames: int) -> void:
	for i in frames:
		await tree.process_frame


func _shot(name: String) -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


## マウスを control の中心へ動かしたことにしてツールチップを出す（本物のカーソルは動かさない）。
func _hover(control: Control) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = control.get_global_transform_with_canvas() * (control.size / 2.0)
	ev.global_position = ev.position
	root.push_input(ev, true)
	await _wait(40)


func _unhover() -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(4, 1070)
	ev.global_position = ev.position
	root.push_input(ev, true)
	await _wait(5)


func _run() -> void:
	var save := root.get_node("SaveManager")
	save.set("run_path", "user://test_saves/capture.json")
	save.call("delete_run")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await _wait(100)   # ロゴ → メニューのフェードイン（約 1.3 秒）を待つ
	await _shot("01_menu")
	await _hover(main.current_screen().get_node("%NewRunButton"))
	await _shot("01b_menu_hover")
	await _unhover()
	main.call("start_new_run", 5)
	await _wait(30)
	await _shot("02_map")
	var run: RunController = main.get("run")
	var id := RunFixtures.force_next(run, MapNode.Type.BATTLE, &"slime_and_louse")
	(main.call("current_screen") as MapScreen).choose_node(id)
	var screen := main.call("current_screen") as CombatScreen
	await _wait(60)
	await _shot("03_combat_drawing")
	while not screen.can_act():
		await tree.process_frame
	await _wait(20)
	await _shot("04_combat_idle")
	await _hover(screen.unit_view(screen.ctl.combat.enemies[0].uid).get_node("%IntentBadge"))
	await _shot("04b_intent_tip")
	await _hover(main.get_node("%TopBarView").get_node("%Relics").get_child(0))
	await _shot("04c_relic_tip")
	await _unhover()
	var v := screen.hand.views()[1]
	for hv in screen.hand.views():
		if not UiText.card_terms(hv.data).is_empty():
			v = hv
	screen.hand.hovered = v
	screen.hand.relayout()
	v.show_tips()
	await _wait(30)
	await _shot("05_combat_hover")
	v.hide_tips()
	screen.hand.hovered = null
	screen.hand.relayout()
	# 照準：対象が必要なカードを持ち上げて矢印を出す。
	for hv in screen.hand.views():
		if screen.ctl.needs_target(hv.card):
			screen.hand_input._on_card_pressed(hv)
			var e := screen.ctl.combat.enemies[0]
			screen.hand_input._update_arrow(screen.unit_view(e.uid).hit_point())
			break
	await _wait(30)
	await _shot("06_combat_aim")
	var target := screen.hand_input.aim_target()
	var card := screen.hand_input.view.card
	screen.hand_input._play(target)
	await _wait(8)
	await _shot("07_combat_hit")
	while not screen.can_act():
		await tree.process_frame
	screen.end_turn()
	await _wait(25)
	await _shot("08_enemy_turn")
	while not screen.can_act():
		await tree.process_frame
	RunFixtures.win_combat(run)
	while not screen.result_pending():
		await tree.process_frame
	await _shot("09_result")
	screen.continue_after_result()
	await _wait(20)
	await _shot("10_reward")
	var reward := main.call("current_screen") as RewardScreen
	for i in run.state.pending_reward.items.size():
		var item := run.state.pending_reward.items[i]
		if item.kind == RewardItem.Kind.CARDS:
			# レアの放射光も写すため、1 枚目をレアにする
			for c: CardData in run.content.cards:
				if c.rarity == CardData.Rarity.RARE:
					item.cards[0] = c
					break
			reward.take(i)
	await _wait(20)
	await _shot("11_card_pick")
	var pick := (main.get_node("%ModalHost") as ModalHost).top() as CardListModal
	await _hover(pick.showcase.views[1])
	await _wait(10)
	await _shot("11b_card_pick_hover")
	await _unhover()
	pick.cancel()
	await _wait(15)
	await _shot("11c_reward_after_skip")
	reward.leave()
	await _wait(10)
	id = RunFixtures.force_next(run, MapNode.Type.SHOP)
	(main.call("current_screen") as MapScreen).choose_node(id)
	var shop := main.call("current_screen") as ShopScreen
	run.state.gold = 260
	shop.rebuild()
	shop.buy(0)
	await _wait(20)
	await _shot("12_shop")
	var sv := shop.offer_views[2] as CardView
	sv.show_tips()
	sv.set_playable(true)
	await _wait(10)
	await _shot("12b_shop_hover")
	sv.hide_tips()
	await _hover(shop.offer_views[shop.offer_views.size() - 1])
	await _shot("12c_shop_potion_tip")
	await _unhover()
	shop.leave()
	id = RunFixtures.force_next(run, MapNode.Type.EVENT, &"wandering_smith")
	(main.call("current_screen") as MapScreen).choose_node(id)
	await _wait(20)
	await _shot("13_event")
	var ev := main.call("current_screen") as EventScreen
	run.state.gold = 200
	ev.rebuild()
	ev.choose(0)
	await _wait(10)
	var modal := (main.get_node("%ModalHost") as ModalHost).top() as CardListModal
	modal.open_compare(0)
	await _wait(10)
	await _shot("14_event_compare")
	modal.confirm_compare()
	await _wait(10)
	await _shot("15_event_result")
	ev.leave()
	await _wait(10)
	id = RunFixtures.force_next(run, MapNode.Type.TREASURE)
	(main.call("current_screen") as MapScreen).choose_node(id)
	await _wait(20)
	await _shot("15b_treasure")
	var treasure := main.call("current_screen") as RewardScreen
	await _hover(treasure.chest)
	await _wait(5)
	await _shot("15c_treasure_hover")
	await _unhover()
	treasure.chest.open()
	await _wait(8)
	await _shot("15d_treasure_open")
	await _wait(16)
	await _shot("15d2_treasure_fountain")
	await _wait(50)
	await _shot("15e_treasure_loot")
	treasure.leave()
	await _wait(10)
	run.state.hp = 40
	id = RunFixtures.force_next(run, MapNode.Type.REST)
	(main.call("current_screen") as MapScreen).choose_node(id)
	await _wait(20)
	await _shot("16_rest")
	var rest := main.call("current_screen") as RestScreen
	await _hover(rest.tiles[0])
	await _wait(10)
	await _shot("16b_rest_hover")
	await _unhover()
	rest.open_upgrade()
	await _wait(10)
	await _shot("17_rest_pick")
	((main.get_node("%ModalHost") as ModalHost).top() as CardListModal).open_compare(1)
	await _wait(10)
	await _shot("18_rest_compare")
	((main.get_node("%ModalHost") as ModalHost).top() as CardListModal).confirm_compare()
	await _wait(30)
	await _shot("19_rest_done")
	save.call("delete_run")
	tree.quit()

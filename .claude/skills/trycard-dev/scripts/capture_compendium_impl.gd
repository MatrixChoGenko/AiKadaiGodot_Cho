extends RefCounted
## capture_compendium.gd から load() される（-s のスクリプトから画面のクラスを静的に参照しないため）。
## 撮る：c01_menu / c02_cards / c03_cards_hover / c04_filtered_upgraded / c05_card_detail / c06_relics / c07_relic_detail / c08_potions

var OUT: String = "user://shots/"
var tree: SceneTree
var root: Window
var main: Node


func start(p_tree: SceneTree) -> void:
	tree = p_tree
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		OUT = user_args[0].replace("\\", "/").trim_suffix("/") + "/"
	root = tree.root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var save := root.get_node("SaveManager")
	save.set("run_path", "user://test_saves/capture.json")
	save.call("delete_run")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await _wait(100)
	await _shot("c01_menu")
	main.call("show_compendium")
	await _wait(40)
	var screen: Control = main.call("current_screen")
	await _shot("c02_cards")
	var views: Array = screen.get("_card_views")
	await _hover(views[8])
	await _shot("c03_cards_hover")
	await _unhover()
	screen.call("toggle_rarity_filter", 1)   # コモン
	screen.call("set_show_upgraded", true)
	screen.call("set_sort", 2)   # コスト順
	await _wait(10)
	await _shot("c04_filtered_upgraded")
	screen.call("clear_filters")
	screen.call("set_show_upgraded", false)
	var shown: Array = screen.call("shown_items")
	var with_up := shown.find_custom(func(c: Resource) -> bool: return c.get(&"upgraded") != null)
	screen.call("open_detail", with_up)
	await _wait(10)
	await _shot("c05_card_detail")
	screen.call("close_detail")
	screen.call("select_tab", 1)
	await _wait(10)
	await _shot("c06_relics")
	screen.call("open_detail", 0)
	await _wait(10)
	await _shot("c07_relic_detail")
	screen.call("select_tab", 2)
	await _wait(10)
	await _shot("c08_potions")
	tree.quit()


func _wait(frames: int) -> void:
	for i in frames:
		await tree.process_frame


func _shot(name: String) -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


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

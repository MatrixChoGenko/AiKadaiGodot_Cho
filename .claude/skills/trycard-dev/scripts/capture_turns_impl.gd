extends RefCounted
## ターンの切り替えの確認用：戦闘の開始から 1 フレームずつ（start_NN）、ターン終了を押してから 1 フレームずつ（end_NN）撮る。
## `--fixed-fps 30` で撮ると、Slay the Spire 2 の録画（30fps の連番）と同じ時間の刻みで並べて比べられる。
## 引数: -- <出力先> [encounter id]（省略時 jawworm）。capture_turns.gd から load() される。

const START_FRAMES: int = 70
const END_FRAMES: int = 66

var OUT: String = "user://shots/"
var tree: SceneTree
var root: Window
var encounter: StringName = &"jawworm"


func start(p_tree: SceneTree) -> void:
	tree = p_tree
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0].replace("\\", "/").trim_suffix("/") + "/"
	if args.size() > 1:
		encounter = StringName(args[1])
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


func _run() -> void:
	var save := root.get_node("SaveManager")
	save.set("run_path", "user://test_saves/capture_turns.json")
	save.call("delete_run")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await _wait(20)
	main.call("start_new_run", 5)
	await _wait(30)
	var run: RunController = main.get("run")
	var id := RunFixtures.force_next(run, MapNode.Type.BATTLE, encounter)
	(main.call("current_screen") as MapScreen).choose_node(id)
	var screen := main.call("current_screen") as CombatScreen
	for i in START_FRAMES:
		await _shot("start_%02d" % i)
	while not screen.can_act():
		await tree.process_frame
	await _wait(10)
	screen.end_turn()
	for i in END_FRAMES:
		await _shot("end_%02d" % i)
	save.call("delete_run")
	tree.quit()

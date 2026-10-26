extends RefCounted
## capture_coop.gd の本体。接続はせず、Net の状態だけを作って画面を出す（コマンドは送らない）。
## coop_01_lobby：ホストの部屋に 4 人。coop_02_combat：4 人の戦闘（自分 = 席 1、味方の 1 人は Ready）。

var OUT: String = "user://shots/"
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
	tree.quit()


func _wait(frames: int) -> void:
	for i in frames:
		await tree.process_frame


func _shot(shot_name: String) -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + shot_name + ".png")
	print("shot ", shot_name)


func _run() -> void:
	var save := root.get_node("SaveManager")
	save.set("run_path", "user://test_saves/capture_coop.json")
	var net := root.get_node("Net")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await _wait(10)
	# ロビー：ホストとして 4 人そろった状態（接続はしない）
	net.set("role", 1)
	net.set("my_name", "ホスト")
	net.set("members", [{peer = 1, name = "ホスト"}, {peer = 2, name = "さとう"}, {peer = 3, name = "すずき"},
			{peer = 4, name = "たなか"}] as Array[Dictionary])
	main.call("show_lobby")
	await _wait(40)
	await _shot("coop_01_lobby")
	# 4 人の戦闘：自分は席 1
	var run := RunController.new(Content.library)
	net.set("seat", 1)
	net.set("run", run)
	main.set("run", run)
	run.phase_changed.connect(func(p: RunPhase.Id) -> void: main.call("show_phase", p))
	run.start_new(11, true, PackedStringArray(["ホスト", "さとう", "すずき", "たなか"]))
	var node := run.choices()[0]
	node.type = MapNode.Type.BATTLE
	node.encounter = &"slime_and_louse"
	run.enter_node(node.id)
	run.combat.end_turn(2)
	await _wait(240)
	await _shot("coop_02_combat")
	net.set("run", null)
	net.set("role", 0)

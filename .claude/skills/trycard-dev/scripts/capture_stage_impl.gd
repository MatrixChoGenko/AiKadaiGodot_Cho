extends RefCounted
## 3D 舞台の確認用：エンカウントごとに 登場 → 待機 → 攻撃（5 フレームおき 12 枚）→ 防御 → 敵のターン（6 フレームおき 24 枚）
## → 撃破（先頭の敵の HP を 1 にしてアタック。4 フレームおき 30 枚）→ 勝利（6 フレームおき 24 枚）を撮る。
## エフェクトの確認では `--fixed-fps 60` を付ける（撮影が遅いので、付けないと 1 枚の間に演出が進みすぎる）。
## 引数: -- <出力先> <encounter id...>（省略時 worm_and_cultist）。capture_stage.gd から load() される。

var OUT: String = "user://shots/"
var tree: SceneTree
var root: Window
var main: Node
var encounters: Array[StringName] = [&"worm_and_cultist"]


func start(p_tree: SceneTree) -> void:
	tree = p_tree
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0].replace("\\", "/").trim_suffix("/") + "/"
	if args.size() > 1:
		encounters.clear()
		for i in range(1, args.size()):
			encounters.append(StringName(args[i]))
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
	save.set("run_path", "user://test_saves/capture_stage.json")
	save.call("delete_run")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await _wait(20)
	main.call("start_new_run", 5)
	await _wait(30)
	var run: RunController = main.get("run")
	var n := 0
	for enc in encounters:
		n += 1
		var id := RunFixtures.force_next(run, MapNode.Type.BATTLE, enc)
		(main.call("current_screen") as MapScreen).choose_node(id)
		var screen := main.call("current_screen") as CombatScreen
		await _wait(10)
		await _shot("%d_%s_00_spawn" % [n, enc])
		while not screen.can_act():
			await tree.process_frame
		await _wait(20)
		await _shot("%d_%s_01_idle" % [n, enc])
		for hv in screen.hand.views():
			if screen.ctl.needs_target(hv.card):
				var target := screen.ctl.combat.alive_enemies()[0]
				screen.try_play(hv.card, target)
				break
		for i in 12:
			await _wait(5)
			await _shot("%d_%s_02_strike_%02d" % [n, enc, i])
		while not screen.can_act():
			await tree.process_frame
		for hv in screen.hand.views():
			if hv.card.data.id == &"defend":
				screen.try_play(hv.card, null)
				break
		for i in 4:
			await _wait(6)
			await _shot("%d_%s_03_defend_%02d" % [n, enc, i])
		while not screen.can_act():
			await tree.process_frame
		screen.end_turn()
		for i in 24:
			await _wait(6)
			await _shot("%d_%s_04_enemy_%02d" % [n, enc, i])
		while not screen.can_act():
			await tree.process_frame
		# 撃破：先頭の敵の HP を 1 にしてからアタックで倒す（死亡の動作とエフェクト）。
		var victim := screen.ctl.combat.alive_enemies()[0]
		victim.hp = 1
		for hv in screen.hand.views():
			if screen.ctl.needs_target(hv.card):
				screen.try_play(hv.card, victim)
				break
		for i in 30:
			await _wait(4)
			await _shot("%d_%s_05_kill_%02d" % [n, enc, i])
		while not screen.can_act():
			await tree.process_frame
		RunFixtures.win_combat(run)
		for i in 24:
			await _wait(6)
			await _shot("%d_%s_06_victory_%02d" % [n, enc, i])
		while not screen.result_pending():
			await tree.process_frame
		screen.continue_after_result()
		await _wait(10)
		var reward := main.call("current_screen") as RewardScreen
		if reward != null:
			reward.leave()
		await _wait(10)
	save.call("delete_run")
	tree.quit()

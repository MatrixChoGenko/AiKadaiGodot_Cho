extends RefCounted
## capture_backdrops.gd から load() される。戦闘画面を戦闘なしで置き、CombatScreen.BACKDROPS の背景ごとに
## エフェクトなし（bd<N>_off.png）と、あり（bd<N>_on_<k>.png、TIMES 秒おき）を撮る。
## 差分を見るときは PIL で off と on を引き算して数倍する（控えめな効果でも位置が分かる）。

const COMBAT_SCENE := "res://scenes/screens/combat.tscn"
## 撮る間隔（フレーム数。--fixed-fps 60 なら 1 秒 = 60）。
const STEP_FRAMES: int = 60
const SHOTS: int = 3

var OUT: String = "user://shots/"
var tree: SceneTree


func start(p_tree: SceneTree) -> void:
	tree = p_tree
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0].replace("\\", "/").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var root := tree.root
	for child in root.get_children():
		if child.name == "Main":
			child.queue_free()
	await tree.process_frame
	var screen: Control = (load(COMBAT_SCENE) as PackedScene).instantiate()
	root.add_child(screen)
	var paths: Array = screen.get_script().get_script_constant_map()["BACKDROPS"]
	var backdrop: TextureRect = screen.get_node("%Backdrop")
	var amb = screen.get_node("%Ambience")
	for i in paths.size():
		var b: Resource = load(paths[i])
		backdrop.texture = b.get("texture")
		amb.call("apply", null)
		await _shot("bd%d_off.png" % (i + 1), 4)
		amb.call("apply", b)
		for k in SHOTS:
			await _shot("bd%d_on_%d.png" % [i + 1, k], STEP_FRAMES if k > 0 else 4)
	tree.quit()


func _shot(file: String, frames: int) -> void:
	for f in frames:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(OUT + file)
	print("shot " + file)

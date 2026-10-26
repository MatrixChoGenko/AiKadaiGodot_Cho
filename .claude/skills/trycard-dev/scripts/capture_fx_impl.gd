extends RefCounted
## 舞台エフェクトの試し撃ち：戦闘と同じ正投影カメラ（1 単位 = 90 ピクセル）の前に、エフェクトを横に並べて同時に出し、
## 3 フレームおきに 16 枚撮る。背景は戦闘の背景画像（透明な舞台を重ねたときの見え方に近づける）。

const FRAMES_BETWEEN: int = 4
const SHOTS: int = 18

var OUT: String = "user://shots/"
var tree: SceneTree


func start(p_tree: SceneTree) -> void:
	tree = p_tree
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0].replace("\\", "/").trim_suffix("/") + "/"
	var kinds: Array = BattleStage.EFFECTS.keys()
	if args.size() > 1:
		kinds = []
		for i in range(1, args.size()):
			kinds.append(StringName(args[i]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var root := tree.root
	var bg := TextureRect.new()
	bg.texture = load("res://assets/textures/backgrounds/battle_forest_ruins_1.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(bg)
	var stage := BattleStage.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	# 先読み（BattleStage._warm_up）でシェーダーのコンパイルが済むまで待つ（最初の数フレームは間隔が長い）。
	for f in 30:
		await tree.process_frame
	var width := 16.0
	var fx_autoload := root.get_node("Fx")
	var screen := root.get_visible_rect().size
	for i in kinds.size():
		var x := -width / 2.0 + width * (i + 0.5) / kinds.size()
		if (fx_autoload.get("SCENES") as Dictionary).has(kinds[i]):
			# 2D（Fx のプール）のエフェクトは画面の同じ横位置に出す。
			fx_autoload.call("spawn", kinds[i], Vector2(screen.x * (i + 0.5) / kinds.size(), screen.y * 0.45), {color = Color(1.0, 0.62, 0.3)})
		else:
			stage.spawn_fx(kinds[i], Vector3(x, 0.0, BattleStage.FX_DEPTH), 1.0, 1.0)
	for n in SHOTS:
		for f in FRAMES_BETWEEN:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "fx_%02d.png" % n)
	tree.quit()

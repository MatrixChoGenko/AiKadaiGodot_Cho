extends RefCounted
## capture_card_fx.gd から load() される。銅・銀・金のカードを並べて撮る。
## glow.png：上の段 = 使用可能（青白）、下の段 = 選択中（金色）。
## shine_NN.png：スイープ光の progress を SHINE_STEPS の値に止めて撮る（流れ方の確認）。
## sparkle_NN.png：フレームのきらめき（銀・金）を時間をずらして撮る。

const CARD_VIEW_SCENE := "res://scenes/widgets/card_view.tscn"
const GAP: float = 48.0
const SHINE_STEPS: Array[float] = [0.15, 0.35, 0.5, 0.65, 0.85]
const SPARKLE_SHOTS: int = 40
const SPARKLE_STEP: int = 9

var OUT: String = "user://shots/"
var tree: SceneTree


func start(p_tree: SceneTree) -> void:
	tree = p_tree
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0].replace("\\", "/").trim_suffix("/") + "/"
	var s := float(args[1]) if args.size() > 1 else 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var root := tree.root
	for child in root.get_children():
		if child.name == "Main":
			child.queue_free()
	await tree.process_frame
	var scene: PackedScene = load(CARD_VIEW_SCENE)
	var lib = root.get_node("Content").get("library")
	var picks: Array = []
	for rarity in [1, 2, 3]:  # CardData.Rarity の COMMON / UNCOMMON / RARE
		for card in lib.cards:
			if card.rarity == rarity:
				picks.append(card)
				break
	var screen := Vector2(root.get_visible_rect().size)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.14)
	bg.size = screen
	root.add_child(bg)
	var base: Vector2 = Vector2(300, 420) * s
	var views: Array = []
	for row in 2:
		for i in picks.size():
			var view: Control = scene.instantiate()
			root.add_child(view)
			view.position = Vector2(GAP + i * (base.x + GAP), GAP + row * (base.y + GAP))
			view.pivot_offset = Vector2.ZERO
			view.scale = Vector2.ONE * s
			view.call("show_card", picks[i], _text(picks[i]))
			view.call("set_playable", true)
			view.call("set_selected", row == 1)
			views.append(view)
	await _shot("glow.png")
	for k in SHINE_STEPS.size():
		for view in views:
			var shine: TextureRect = view.get_node("%Shine")
			shine.visible = true
			(shine.material as ShaderMaterial).set_shader_parameter(&"progress", SHINE_STEPS[k])
		await _shot("shine_%02d.png" % k)
	# きらめき：グロー・スイープ光を消して SPARKLE_SHOTS 枚を SPARKLE_STEP フレームおきに撮る（--fixed-fps 60 で）。
	# 全部の明るい方を取って重ねると、きらめきの出る場所の分布が 1 枚で分かる。
	for view in views:
		view.get_node("%Shine").visible = false
		view.call("set_playable", false)
		view.call("set_selected", false)
	for k in SPARKLE_SHOTS:
		await _shot("sparkle_%02d.png" % k, SPARKLE_STEP)
	tree.quit()


func _shot(file: String, frames: int = 4) -> void:
	for f in frames:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(OUT + file)
	print("shot " + file)


func _text(data) -> String:
	return load("res://src/presentation/common/ui_text.gd").card_text(data)

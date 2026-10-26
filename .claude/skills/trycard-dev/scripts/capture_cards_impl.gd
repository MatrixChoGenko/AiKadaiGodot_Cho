extends RefCounted
## capture_cards.gd から load() される。カードを 1 画面に並べられるだけ並べて cards_NN.png に撮る。
## scale（既定 1.0）を 0.78 にすると手札での見え方になる。

const CARD_VIEW_SCENE := "res://scenes/widgets/card_view.tscn"
const GAP: float = 16.0

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
	var list: Array = []
	for card in lib.cards:
		if not list.has(card):
			list.append(card)
		if card.upgraded != null and not list.has(card.upgraded):
			list.append(card.upgraded)
	var screen := Vector2(root.get_visible_rect().size)
	var base: Vector2 = Vector2(300, 420) * s
	var cols := int((screen.x - GAP) / (base.x + GAP))
	var rows := int((screen.y - GAP) / (base.y + GAP))
	var page := 0
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.14)
	bg.size = screen
	root.add_child(bg)
	while page * cols * rows < list.size():
		var holder := Control.new()
		root.add_child(holder)
		for i in cols * rows:
			var index := page * cols * rows + i
			if index >= list.size():
				break
			var view: Control = scene.instantiate()
			holder.add_child(view)
			view.position = Vector2(GAP + (i % cols) * (base.x + GAP), GAP + (i / cols) * (base.y + GAP))
			view.pivot_offset = Vector2.ZERO
			view.scale = Vector2.ONE * s
			view.call("show_card", list[index], _text(list[index]))
		for f in 4:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "cards_%02d.png" % page)
		print("shot cards_%02d" % page)
		holder.queue_free()
		page += 1
	tree.quit()


func _text(data) -> String:
	return load("res://src/presentation/common/ui_text.gd").card_text(data)

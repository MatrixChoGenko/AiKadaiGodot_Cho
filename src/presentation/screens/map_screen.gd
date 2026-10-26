class_name MapScreen extends Screen
## ⑤ Presentation：マップ画面（GameDesign §4.2 / §15.3、U03）。ノードのクリック → run.enter_node()。

## EULA で公開リポジトリに置けないので Git には入れていない（.gitignore）。無い PC では PaperFallback の紙色だけになる。
const PAPER_PATH := "res://assets/textures/backgrounds/map_paper.png"

@onready var _paper: TextureRect = %Paper
@onready var _scroll: ScrollContainer = %Scroll
@onready var _map_view: MapView = %MapView
@onready var _title: Label = %ActTitle
@onready var _legend: VBoxContainer = %Legend

var _votes: Array[Label] = []


func _ready() -> void:
	if ResourceLoader.exists(PAPER_PATH):
		_paper.texture = load(PAPER_PATH)


func enter(args: Dictionary) -> void:
	super.enter(args)
	_title.text = "第 %d アクト　%s" % [run.state.act_index + 1, run.act().name]
	var ids: Array[int] = []
	for n in run.choices():
		ids.append(n.id)
	_map_view.show_map(run.state.map, run.state.node_id, run.state.visited, ids)
	_map_view.node_pressed.connect(choose_node)
	_build_legend()
	_scroll_to_current.call_deferred()
	show_votes.call_deferred()


## ノードを選ぶ（クリックと同じ経路。テストからも使う）。協力プレイでは投票（全員が投票したら決まる）。
## 1 人プレイでは進めたか、協力プレイでは投票を送ったかを返す。
func choose_node(node_id: int) -> bool:
	var result := [false]
	Party.act(run, CoopCommands.VOTE, {node = node_id}, func(ok: bool) -> void: result[0] = ok)
	if Party.coop():
		return true
	return result[0]


## 協力プレイ：誰がどのノードに投票したかを、ノードの上に名前で出す（投票が変わるたびに Main から呼ばれる）。
func show_votes() -> void:
	for child in _votes:
		child.queue_free()
	_votes.clear()
	if not Party.coop():
		return
	var stacked: Dictionary[int, int] = {}
	for p in run.state.players:
		if p.vote < 0:
			continue
		var node := run.state.map.node(p.vote)
		if node == null:
			continue
		var label := Label.new()
		label.text = p.name
		label.theme_type_variation = &"LabelSmall"
		label.add_theme_color_override(&"font_color", Party.color(p.index))
		label.add_theme_color_override(&"font_outline_color", Color(0.1, 0.07, 0.05))
		label.add_theme_constant_override(&"outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n: int = stacked.get(p.vote, 0)
		stacked[p.vote] = n + 1
		_map_view.add_child(label)
		label.position = _map_view.node_center(node) + Vector2(34, -34 + 26 * n)
		_votes.append(label)


func _scroll_to_current() -> void:
	var node := run.state.current_node()
	var y := _map_view.custom_minimum_size.y if node == null else _map_view.node_center(node).y
	_scroll.scroll_vertical = int(y - _scroll.size.y * 0.7)


func _build_legend() -> void:
	for t: MapNode.Type in UiGlyphs.NODE_GLYPHS:
		var row := HBoxContainer.new()
		var badge := GlyphBadge.new()
		badge.custom_minimum_size = Vector2(40, 40)
		badge.setup(UiGlyphs.NODE_GLYPHS[t], UiGlyphs.NODE_COLORS[t])
		badge.icon = UiGlyphs.NODE_ICONS.get(t)
		if badge.icon != null:
			badge.outline_width = 0.0
		row.add_child(badge)
		var label := Label.new()
		label.text = UiText.node_type(t)
		label.theme_type_variation = &"LabelSmall"
		row.add_child(label)
		_legend.add_child(row)

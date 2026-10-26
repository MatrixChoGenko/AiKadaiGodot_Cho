class_name MapView extends Control
## ⑤ Presentation：マップの描画（GameDesign §4.2、U03）。ノードは下から上へ並べ、ノード間に線を引く。
## クリックできるのは choices のノードだけ（呼吸アニメーション）。通過済みは印、到達できないノードは暗くする。

signal node_pressed(node_id: int)

const COL_W: float = 150.0
const ROW_H: float = 120.0
const MARGIN: float = 110.0
const NODE_SIZE: float = 68.0
const BOSS_SIZE: float = 130.0
## 羊皮紙の上に描くインクの色。
const INK_PATH := Color(0.27, 0.18, 0.11, 0.6)
const INK_WALKED := Color(0.55, 0.12, 0.07, 0.95)
const INK_CHOICE := Color(0.62, 0.1, 0.05)
const INK_CURRENT := Color(0.12, 0.07, 0.03)
const INK_VISITED := Color(0.3, 0.2, 0.12, 0.8)

var _map: MapGraph
var _visited: PackedInt32Array = PackedInt32Array()
var _choices: Array[int] = []
var _badges: Dictionary[int, GlyphBadge] = {}


func show_map(map: MapGraph, current: int, visited: PackedInt32Array, choices: Array[int]) -> void:
	_map = map
	_visited = visited
	_choices = choices
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_badges.clear()
	custom_minimum_size = Vector2(MARGIN * 2.0 + (map.columns - 1) * COL_W, MARGIN * 2.0 + map.rows * ROW_H + BOSS_SIZE / 2.0)
	var reachable := map.reachable_from(current) if current >= 0 else PackedInt32Array()
	for n in map.nodes:
		var badge := GlyphBadge.new()
		var s := BOSS_SIZE if n.type == MapNode.Type.BOSS else NODE_SIZE
		badge.custom_minimum_size = Vector2(s, s)
		badge.size = Vector2(s, s)
		badge.pivot_offset = badge.size / 2.0
		badge.position = node_center(n) - badge.size / 2.0
		badge.setup(UiGlyphs.NODE_GLYPHS.get(n.type, "?"), UiGlyphs.NODE_COLORS.get(n.type, Color.GRAY))
		badge.icon = UiGlyphs.NODE_ICONS.get(n.type)
		if badge.icon != null:
			badge.outline_width = 0.0   # 画像のノードは状態を示すときだけ円で囲む
		badge.tooltip_text = UiText.node_type(n.type)
		var is_choice := choices.has(n.id)
		var is_visited := visited.has(n.id)
		if is_choice:
			badge.outline = INK_CHOICE
			badge.outline_width = 6.0
			badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var t := badge.create_tween().set_loops()
			t.tween_property(badge, "scale", Vector2.ONE * 1.15, 0.55).set_trans(Tween.TRANS_SINE)
			t.tween_property(badge, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
		elif n.id == current:
			badge.outline = INK_CURRENT
			badge.outline_width = 6.0
		elif is_visited:
			badge.fill = badge.fill.darkened(0.45)
			badge.outline = INK_VISITED
			badge.outline_width = 3.0
			if badge.icon != null:
				badge.modulate = Color(0.65, 0.6, 0.55)
		elif current >= 0 and not reachable.has(n.id):
			badge.modulate.a = 0.35
		badge.gui_input.connect(_on_badge_gui_input.bind(n.id))
		add_child(badge)
		_badges[n.id] = badge
	queue_redraw()


func node_center(n: MapNode) -> Vector2:
	var x := MARGIN + n.col * COL_W
	if n.type == MapNode.Type.BOSS:
		x = MARGIN + (_map.columns - 1) * COL_W / 2.0
	return Vector2(x, custom_minimum_size.y - MARGIN - n.row * ROW_H)


func badge_of(node_id: int) -> GlyphBadge:
	return _badges.get(node_id)


func _draw() -> void:
	if _map == null:
		return
	for n in _map.nodes:
		for next_id in n.next:
			var m := _map.node(next_id)
			var walked := _visited.has(n.id) and _visited.has(m.id)
			var color := INK_WALKED if walked else INK_PATH
			draw_dashed_line(node_center(n), node_center(m), color, 4.0 if walked else 3.0, 10.0, true, true)


func _on_badge_gui_input(event: InputEvent, node_id: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _choices.has(node_id):
		accept_event()
		node_pressed.emit(node_id)

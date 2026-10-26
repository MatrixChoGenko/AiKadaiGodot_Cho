class_name PotionBar extends HBoxContainer
## ⑤ Presentation：ポーション枠（GameDesign §10 / §15.1）。枠をクリックすると小さなメニュー（使う / 捨てる）を出す。
## メニューに出す操作は持ち主（TopBar / CombatScreen）が actions_provider で決め、選ばれたら action_chosen で知らせる。

signal action_chosen(slot: int, action: StringName)

const ACTION_USE: StringName = &"use"
const ACTION_DISCARD: StringName = &"discard"
const SLOT_SIZE: Vector2 = Vector2(52, 52)
## 空き枠の瓶の影。
const EMPTY_ICON: Texture2D = preload("res://assets/textures/ui/hud/potion_empty.png")

## func(slot: int) -> Array[Array]：[[action: StringName, label: String, enabled: bool], ...]。空ならメニューを出さない。
var actions_provider: Callable = Callable()

var _slots: Array[PotionData] = []
var _menu: PanelContainer
var _menu_slot: int = -1


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	_menu = PanelContainer.new()
	_menu.theme_type_variation = &"PanelTooltip"
	_menu.top_level = true
	_menu.z_index = 100
	_menu.visible = false
	_menu.add_child(VBoxContainer.new())
	add_child(_menu)


func show_potions(slots: Array[PotionData]) -> void:
	_slots = slots.duplicate()
	for child in get_children():
		if child != _menu:
			remove_child(child)
			child.queue_free()
	for i in _slots.size():
		var badge := GlyphBadge.new()
		badge.custom_minimum_size = SLOT_SIZE
		badge.shape = GlyphBadge.Shape.DIAMOND
		var potion := _slots[i]
		if potion == null:
			badge.icon = EMPTY_ICON
			badge.outline_width = 0.0
			badge.modulate.a = 0.55
			badge.tooltip_text = "空き"
		else:
			badge.setup(UiGlyphs.first_char(potion.name), UiGlyphs.POTION_COLORS.get(potion.rarity, Color.GRAY), GlyphBadge.Shape.DIAMOND)
			badge.icon = UiGlyphs.potion_icon(potion)
			if badge.icon != null:
				badge.outline_width = 0.0
				badge.icon_ratio = 1.0
			badge.tooltip_text = UiText.potion_text(potion)
			badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		badge.gui_input.connect(_on_slot_gui_input.bind(i, badge))
		add_child(badge)
	_hide_menu()


## テストと自動操作用：メニューを経由せずに操作を選ぶ。
func choose(slot: int, action: StringName) -> void:
	_hide_menu()
	action_chosen.emit(slot, action)


func slot_count() -> int:
	return _slots.size()


func _on_slot_gui_input(event: InputEvent, slot: int, badge: Control) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if slot >= _slots.size() or _slots[slot] == null or not actions_provider.is_valid():
		return
	var actions: Array = actions_provider.call(slot)
	if actions.is_empty():
		return
	var box := _menu.get_child(0) as VBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = _slots[slot].name
	title.theme_type_variation = &"LabelSmall"
	box.add_child(title)
	for a: Array in actions:
		var b := Button.new()
		b.text = a[1]
		b.disabled = not a[2]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(choose.bind(slot, a[0] as StringName))
		box.add_child(b)
	_menu_slot = slot
	_menu.visible = true
	_menu.reset_size()
	_menu.global_position = badge.global_position + Vector2(0, SLOT_SIZE.y + 6)


func _input(event: InputEvent) -> void:
	if not _menu.visible:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and not _menu.get_global_rect().has_point(mb.global_position):
		_hide_menu()


func _hide_menu() -> void:
	if _menu != null:
		_menu.visible = false
	_menu_slot = -1

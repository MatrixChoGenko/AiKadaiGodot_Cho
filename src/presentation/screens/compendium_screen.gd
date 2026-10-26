class_name CompendiumScreen extends Screen
## ⑤ Presentation：図鑑（メインメニューから開く。ランの外の画面）。2026-10-22 の決定：
## - タブ = カード / レリック / ポーション。最初から全部見える（アンロック・発見の記録はしない）。
## - カードは強化版を除く全カード（初期・状態異常・呪いを含む）。「強化版を表示」で強化できるカードだけ強化後の面に替える（StS と同じ）。
## - 左の列で絞り込み（カード = 種類とレアリティ、ほか = レアリティ。同じ列の中は「または」、列どうしは「かつ」。何も押していなければすべて）と並べ替え。件数は「表示中 / 全体」。
## - クリックで拡大（カード = 強化前 → 強化後と用語の説明、レリック / ポーション = 大きなアイコンと説明）。Esc / 暗幕のクリックで閉じる。
## 見た目：タイトルの背景の絵をぼかして暗くしたもの。各タブの一覧は最初に 1 回だけ作り、絞り込み・並べ替えは表示 / 並び順の入れ替えだけで行う。

## メインメニューへ戻りたい（Main がつなぐ）。
signal back_requested

enum Tab { CARDS, RELICS, POTIONS }
enum Sort { RARITY, TYPE, COST, NAME }

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/widgets/card_view.tscn")
const BACKDROP: Texture2D = preload("res://assets/textures/backgrounds/title_campfire.jpg")
const BLUR_SHADER: Shader = preload("res://assets/shaders/backdrop_blur.gdshader")
const BANNER_FONT: Font = preload("res://assets/fonts/banner_mincho.ttf")

const TAB_NAMES: Dictionary[Tab, String] = {Tab.CARDS: "カード", Tab.RELICS: "レリック", Tab.POTIONS: "ポーション"}
const SORT_NAMES: Dictionary[Sort, String] = {
	Sort.RARITY: "レアリティ順", Sort.TYPE: "種類順", Sort.COST: "コスト順", Sort.NAME: "名前順",
}
## タブごとに選べる並べ替え。
const SORTS: Dictionary[Tab, Array] = {
	Tab.CARDS: [Sort.RARITY, Sort.TYPE, Sort.COST, Sort.NAME],
	Tab.RELICS: [Sort.RARITY, Sort.NAME],
	Tab.POTIONS: [Sort.RARITY, Sort.NAME],
}
## 種類の絞り込みの区分（番号 = type_group()）。ステータスと呪いは 1 つにまとめる。
const TYPE_GROUPS: Array[String] = ["アタック", "スキル", "パワー", "ステータス・呪い"]
## 並べ替えのコストの値：X は 9 より後、プレイ不可は最後。
const COST_X: int = 10
const COST_UNPLAYABLE: int = 11

## 一覧のカードの縮小率と列の数（1920 幅で左の列 300 + 余白に収まる）。
const CARD_SCALE: float = 0.62
const CARD_COLUMNS: int = 6
const HOVER_SCALE: float = 1.08
const HOVER_SECONDS: float = 0.1
const DETAIL_SCALE: float = 1.3
## 拡大表示の暗幕（一覧がはっきり透けると読みにくいので PanelDim より暗い）。
const DETAIL_DIM: Color = Color(0.02, 0.03, 0.05, 0.82)
const ICON_SIZE: Vector2 = Vector2(110, 110)
const ICON_COLUMNS: int = 7
const DETAIL_ICON_SIZE: Vector2 = Vector2(220, 220)
const SIDEBAR_WIDTH: float = 300.0

var tab: Tab = Tab.CARDS
var show_upgraded: bool = false
## 種類の絞り込み（TYPE_GROUPS の番号）。空 = すべて。
var type_filter: Array[int] = []
## タブごとのレアリティの絞り込み（各データの Rarity の値）。空 = すべて。
var rarity_filter: Dictionary[Tab, Array] = {Tab.CARDS: [], Tab.RELICS: [], Tab.POTIONS: []}
var sort_mode: Dictionary[Tab, Sort] = {Tab.CARDS: Sort.RARITY, Tab.RELICS: Sort.RARITY, Tab.POTIONS: Sort.RARITY}

## タブ → 元のデータ（ライブラリの順）と、同じ番号の一覧の枠。
var _data: Dictionary[Tab, Array] = {}
var _cells: Dictionary[Tab, Array] = {}
var _card_views: Array[CardView] = []
var _scrolls: Dictionary[Tab, ScrollContainer] = {}
var _grids: Dictionary[Tab, GridContainer] = {}
var _tab_buttons: Dictionary[Tab, Button] = {}
var _sidebar: VBoxContainer
var _count_label: Label
var _detail: Control
var _detail_body: HBoxContainer
## 拡大表示しているもの（null = 閉じている）。
var _detail_item: Resource


func _ready() -> void:
	_build_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override(&"margin_top", 24)
	margin.add_theme_constant_override(&"margin_bottom", 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	margin.add_child(column)
	column.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 28)
	column.add_child(body)
	var side := PanelContainer.new()
	side.theme_type_variation = &"PanelHud"
	side.custom_minimum_size = Vector2(SIDEBAR_WIDTH, 0)
	body.add_child(side)
	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override(&"separation", 10)
	side.add_child(_sidebar)
	var lists := Control.new()
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(lists)
	var lib := Content.library
	_data[Tab.CARDS] = lib.base_cards()
	_data[Tab.RELICS] = lib.relics.duplicate()
	_data[Tab.POTIONS] = lib.potions.duplicate()
	for t: Tab in TAB_NAMES:
		lists.add_child(_build_list(t))
	_build_detail()
	select_tab(Tab.CARDS)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if detail_open():
		close_detail()
	else:
		back_requested.emit()


# —— 操作（テストからも呼ぶ。ボタンと同じ経路） ——

func select_tab(t: Tab) -> void:
	close_detail()
	tab = t
	for k: Tab in _scrolls:
		_scrolls[k].visible = k == t
		_tab_buttons[k].set_pressed_no_signal(k == t)
	_build_sidebar()
	_apply()


func toggle_type_filter(group: int) -> void:
	if type_filter.has(group):
		type_filter.erase(group)
	else:
		type_filter.append(group)
	_apply()


## rarity は今のタブのデータの Rarity の値。
func toggle_rarity_filter(rarity: int) -> void:
	var list: Array = rarity_filter[tab]
	if list.has(rarity):
		list.erase(rarity)
	else:
		list.append(rarity)
	_apply()


func clear_filters() -> void:
	if tab == Tab.CARDS:
		type_filter.clear()
	rarity_filter[tab].clear()
	_build_sidebar()
	_apply()


func set_sort(mode: Sort) -> void:
	sort_mode[tab] = mode
	_apply()


func set_show_upgraded(on: bool) -> void:
	show_upgraded = on
	var cards: Array = _data[Tab.CARDS]
	for i in cards.size():
		var d: CardData = cards[i]
		var shown := d.upgraded if on and d.upgraded != null else d
		if _card_views[i].data != shown:
			_card_views[i].show_card(shown, UiText.card_text(shown))


## 今のタブで表示している物（表示順）。
func shown_items() -> Array:
	var items: Array = []
	for i in _order(tab):
		items.append(_data[tab][i])
	return items


func total_count(t: Tab = tab) -> int:
	return _data[t].size()


## 表示中の index 番目を拡大する（クリックと同じ経路）。
func open_detail(index: int) -> void:
	var order := _order(tab)
	if index < 0 or index >= order.size():
		return
	_open_detail_of(_data[tab][order[index]])


func close_detail() -> void:
	_detail_item = null
	if _detail == null:
		return
	_detail.visible = false
	_clear(_detail_body)


func detail_open() -> bool:
	return _detail_item != null


## 拡大表示で並べているカード（強化前、あれば強化後）。
func detail_cards() -> Array[CardView]:
	var views: Array[CardView] = []
	for slot in _detail_body.get_children():
		for child in slot.get_children():
			if child is CardView:
				views.append(child)
	return views


func back() -> void:
	back_requested.emit()


# —— 絞り込み・並べ替え（静的。テストで直接使う） ——

static func type_group(t: CardData.Type) -> int:
	return mini(int(t), TYPE_GROUPS.size() - 1)


static func cost_key(d: CardData) -> int:
	match d.cost_mode:
		CardData.CostMode.X:
			return COST_X
		CardData.CostMode.UNPLAYABLE:
			return COST_UNPLAYABLE
	return d.cost


## 並べ替えの比較の鍵（前から順に比べる。最後の id で順番を一意にする）。
static func sort_key(item: Resource, mode: Sort) -> Array:
	var card := item as CardData
	if card != null:
		var rarity := int(card.rarity)
		var type := int(card.type)
		var cost := cost_key(card)
		match mode:
			Sort.TYPE:
				return [type, rarity, cost, card.name, String(card.id)]
			Sort.COST:
				return [cost, rarity, type, card.name, String(card.id)]
			Sort.NAME:
				return [card.name, String(card.id)]
		return [rarity, type, cost, card.name, String(card.id)]
	var relic := item as RelicData
	if relic != null:
		return [relic.name, String(relic.id)] if mode == Sort.NAME else [int(relic.rarity), relic.name, String(relic.id)]
	var potion := item as PotionData
	return [potion.name, String(potion.id)] if mode == Sort.NAME else [int(potion.rarity), potion.name, String(potion.id)]


static func key_less(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] < b[i]
	return a.size() < b.size()


func _passes(item: Resource) -> bool:
	var rarities: Array = rarity_filter[tab]
	var card := item as CardData
	if card != null:
		if not type_filter.is_empty() and not type_filter.has(type_group(card.type)):
			return false
		return rarities.is_empty() or rarities.has(int(card.rarity))
	var relic := item as RelicData
	if relic != null:
		return rarities.is_empty() or rarities.has(int(relic.rarity))
	return rarities.is_empty() or rarities.has(int((item as PotionData).rarity))


## 今のタブで表示する物の番号（_data の番号、表示順）。
func _order(t: Tab) -> Array[int]:
	var items: Array = _data[t]
	var keys := {}
	var order: Array[int] = []
	for i in items.size():
		if _passes(items[i]):
			order.append(i)
			keys[i] = sort_key(items[i], sort_mode[t])
	order.sort_custom(func(a: int, b: int) -> bool: return key_less(keys[a], keys[b]))
	return order


## 絞り込み・並べ替えを一覧に反映する（枠は作り直さず、表示と並び順だけ変える）。
func _apply() -> void:
	var order := _order(tab)
	var cells: Array = _cells[tab]
	var grid := _grids[tab]
	var shown := {}
	for pos in order.size():
		var cell: Control = cells[order[pos]]
		grid.move_child(cell, pos)
		shown[order[pos]] = true
	for i in cells.size():
		(cells[i] as Control).visible = shown.has(i)
	_count_label.text = "表示中　%d / %d" % [order.size(), total_count()]
	_scrolls[tab].scroll_vertical = 0


# —— 見た目 ——

func _build_backdrop() -> void:
	var bg := TextureRect.new()
	bg.texture = BACKDROP
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	bg.material = mat
	add_child(bg)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 36)
	var title := Label.new()
	title.text = "図鑑"
	title.add_theme_font_override(&"font", BANNER_FONT)
	title.add_theme_font_size_override(&"font_size", 60)
	title.add_theme_color_override(&"font_color", Color(1, 0.84, 0.4))
	title.add_theme_color_override(&"font_outline_color", Color(0.03, 0.04, 0.07))
	title.add_theme_constant_override(&"outline_size", 12)
	row.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 20)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(tabs)
	var group := ButtonGroup.new()
	for t: Tab in TAB_NAMES:
		var b := _title_button(TAB_NAMES[t])
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(select_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	var back_button := _title_button("戻る")
	back_button.pressed.connect(back)
	row.add_child(back_button)
	return row


func _title_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"ButtonTitle"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## タブ 1 つ分の一覧（スクロール + 格子）。枠はここで 1 回だけ作る。
func _build_list(t: Tab) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = CARD_COLUMNS if t == Tab.CARDS else ICON_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 28 if t == Tab.CARDS else 36)
	grid.add_theme_constant_override(&"v_separation", 28 if t == Tab.CARDS else 40)
	center.add_child(grid)
	var cells: Array = []
	for item: Resource in _data[t]:
		var cell := _card_cell(item as CardData) if t == Tab.CARDS else _icon_cell(item)
		grid.add_child(cell)
		cells.append(cell)
	_cells[t] = cells
	_grids[t] = grid
	_scrolls[t] = scroll
	return scroll


## カードの枠：縮小後の大きさの Control の中央に、中心を軸にして縮めた CardView を置く（ホバーで中心から少し大きくする）。
func _card_cell(data: CardData) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = CardView.BASE_SIZE * CARD_SCALE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	view.mouse_filter = Control.MOUSE_FILTER_PASS   # ホイールは ScrollContainer へ通す
	view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cell.add_child(view)
	view.position = cell.custom_minimum_size / 2.0 - view.pivot_offset
	view.scale = Vector2.ONE * CARD_SCALE
	view.show_card(data, UiText.card_text(data))
	view.pressed.connect(func(v: CardView) -> void: _open_detail_of(_data[Tab.CARDS][_card_views.find(v)]))
	view.mouse_entered.connect(_hover_card.bind(cell, view, true))
	view.mouse_exited.connect(_hover_card.bind(cell, view, false))
	_card_views.append(view)
	return cell


func _hover_card(cell: Control, view: CardView, on: bool) -> void:
	cell.z_index = 1 if on else 0
	view.create_tween().tween_property(view, "scale", Vector2.ONE * CARD_SCALE * (HOVER_SCALE if on else 1.0), HOVER_SECONDS)


## レリック / ポーションの枠：アイコン + 名前。ホバーで説明のツールチップ、クリックで拡大。
func _icon_cell(item: Resource) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(170, 0)
	column.add_theme_constant_override(&"separation", 8)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(center)
	var badge := _badge(item, ICON_SIZE)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_open_detail_of(item))
	center.add_child(badge)
	var label := Label.new()
	label.text = _item_name(item)
	label.theme_type_variation = &"LabelSmall"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return column


func _badge(item: Resource, badge_size: Vector2) -> GlyphBadge:
	var badge := GlyphBadge.new()
	badge.custom_minimum_size = badge_size
	var relic := item as RelicData
	if relic != null:
		badge.setup(UiGlyphs.first_char(relic.name), UiGlyphs.RELIC_COLORS.get(relic.rarity, Color.GRAY), GlyphBadge.Shape.ROUNDED)
		badge.tooltip_text = UiText.relic_text(relic)
		badge.icon = UiGlyphs.relic_icon(relic)
	else:
		var potion := item as PotionData
		badge.setup(UiGlyphs.first_char(potion.name), UiGlyphs.POTION_COLORS.get(potion.rarity, Color.GRAY), GlyphBadge.Shape.DIAMOND)
		badge.tooltip_text = UiText.potion_text(potion)
		badge.icon = UiGlyphs.potion_icon(potion)
	if badge.icon != null:
		badge.outline_width = 0.0
		badge.icon_ratio = 0.9
	return badge


func _item_name(item: Resource) -> String:
	var relic := item as RelicData
	return relic.name if relic != null else (item as PotionData).name


func _rarity_name(item: Resource) -> String:
	var card := item as CardData
	if card != null:
		return UiText.rarity(card.rarity)
	var relic := item as RelicData
	if relic != null:
		return UiText.RELIC_RARITIES.get(relic.rarity, "")
	return UiText.POTION_RARITIES.get((item as PotionData).rarity, "")


## 左の列（タブを替えるたびに作り直す）。
func _build_sidebar() -> void:
	_clear(_sidebar)
	if tab == Tab.CARDS:
		_section("種類")
		var types := _toggle_grid()
		for g in TYPE_GROUPS.size():
			_toggle(types, TYPE_GROUPS[g], type_filter.has(g), toggle_type_filter.bind(g))
	_section("レアリティ")
	var rarities := _toggle_grid()
	for r: int in _rarities_of(tab):
		var label: String
		match tab:
			Tab.CARDS:
				label = UiText.rarity(r as CardData.Rarity)
			Tab.RELICS:
				label = UiText.RELIC_RARITIES[r as RelicData.Rarity]
			_:
				label = UiText.POTION_RARITIES[r as PotionData.Rarity]
		_toggle(rarities, label, rarity_filter[tab].has(r), toggle_rarity_filter.bind(r))
	_section("並べ替え")
	var sorts := _toggle_grid()
	var group := ButtonGroup.new()
	for s: Sort in SORTS[tab]:
		var b := _toggle(sorts, SORT_NAMES[s], sort_mode[tab] == s, set_sort.bind(s))
		b.button_group = group
	if tab == Tab.CARDS:
		var upgraded := CheckBox.new()
		upgraded.text = "強化版を表示"
		upgraded.focus_mode = Control.FOCUS_NONE
		upgraded.button_pressed = show_upgraded
		upgraded.toggled.connect(set_show_upgraded)
		_sidebar.add_child(upgraded)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar.add_child(spacer)
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sidebar.add_child(_count_label)
	var clear := Button.new()
	clear.text = "絞り込みを解除"
	clear.focus_mode = Control.FOCUS_NONE
	clear.pressed.connect(clear_filters)
	_sidebar.add_child(clear)


## 今のタブのデータにあるレアリティ（値の昇順。データに無いレアリティのボタンは出さない）。
func _rarities_of(t: Tab) -> Array[int]:
	var found := {}
	for item: Resource in _data[t]:
		var card := item as CardData
		var relic := item as RelicData
		var r: int = int(card.rarity) if card != null else (int(relic.rarity) if relic != null else int((item as PotionData).rarity))
		found[r] = true
	var result: Array[int] = []
	for r: int in found:
		result.append(r)
	result.sort()
	return result


func _section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(1, 0.84, 0.4))
	_sidebar.add_child(label)


func _toggle_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	_sidebar.add_child(grid)
	return grid


func _toggle(parent: Container, text: String, on: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", 17)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


# —— 拡大表示 ——

func _build_detail() -> void:
	_detail = Control.new()
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.visible = false
	add_child(_detail)
	var dim := ColorRect.new()
	dim.color = DETAIL_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed:
			close_detail())
	_detail.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	_detail_body = HBoxContainer.new()
	_detail_body.add_theme_constant_override(&"separation", 40)
	_detail_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_detail_body)
	var close_button := Button.new()
	close_button.text = "閉じる"
	close_button.custom_minimum_size = Vector2(240, 64)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_detail)
	column.add_child(close_button)


func _open_detail_of(item: Resource) -> void:
	_clear(_detail_body)
	_detail_item = item
	var card := item as CardData
	if card != null:
		_detail_body.add_child(_detail_card(card))
		if card.upgraded != null:
			var arrow := Label.new()
			arrow.text = "▶"
			arrow.add_theme_font_size_override(&"font_size", 48)
			arrow.add_theme_color_override(&"font_color", Color(1, 0.84, 0.4))
			_detail_body.add_child(arrow)
			_detail_body.add_child(_detail_card(card.upgraded))
		var cost := UiText.cost_label(card)
		var info := "%s　%s　%s" % [UiText.card_type(card.type), _rarity_name(card), "プレイ不可" if cost.is_empty() else "コスト " + cost]
		_detail_body.add_child(_detail_text(card.name, info, UiText.card_terms(card)))
	else:
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge := _badge(item, DETAIL_ICON_SIZE)
		badge.tooltip_text = ""
		holder.add_child(badge)
		_detail_body.add_child(holder)
		var text := UiText.relic_text(item as RelicData) if item is RelicData else UiText.potion_text(item as PotionData)
		var lines := text.split("\n", true, 1)
		var kind := "レリック" if item is RelicData else "ポーション"
		_detail_body.add_child(_detail_text(lines[0], "%s　%s" % [kind, _rarity_name(item)], [], lines[1] if lines.size() > 1 else ""))
	_detail.visible = true


func _detail_card(data: CardData) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = CardView.BASE_SIZE * DETAIL_SCALE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	view.tips_enabled = false
	slot.add_child(view)
	view.show_card(data, UiText.card_text(data))
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2.ONE * DETAIL_SCALE
	return slot


## 右側の説明：名前・種類などの 1 行・本文（BBCode）・用語の説明。
func _detail_text(title: String, info: String, terms: Array, body: String = "") -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(420, 0)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override(&"separation", 12)
	var name_label := Label.new()
	name_label.text = title
	name_label.theme_type_variation = &"LabelLarge"
	column.add_child(name_label)
	var info_label := Label.new()
	info_label.text = info
	info_label.modulate = Color(1, 1, 1, 0.75)
	column.add_child(info_label)
	var markup := body
	for term: Array in terms:
		if not markup.is_empty():
			markup += "\n\n"
		markup += "[color=#%s]%s[/color]\n%s" % [UiText.TERM_COLOR.to_html(false), term[0], term[1]]
	if not markup.is_empty():
		var rich := RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.custom_minimum_size = Vector2(420, 0)
		rich.text = markup
		rich.add_theme_font_size_override(&"normal_font_size", 21)
		column.add_child(rich)
	return column


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

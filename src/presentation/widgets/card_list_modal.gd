class_name CardListModal extends Modal
## ⑤ Presentation：汎用のカード一覧パネル（GameDesign §15.1）。選択と閲覧を兼ねる。
## 報酬の 3 択 / 削除 / アップグレード / イベントのカード選択 / 戦闘中のカード選択 / 山とデッキの閲覧で共用する。
##
## enter(args) の引数：
##   title: String、info: String（補足の 1 行）
##   entries: Array[Dictionary]（{data: CardData, text: String, card: Card（任意）, cost: int（任意）}）
##   min_count / max_count: int（max_count = 0 なら閲覧だけ）
##   cancellable: bool、cancel_text: String、confirm_text: String
##   upgrade_preview: bool（アップグレードするカードを選ぶとき。1 枚選びのときだけ効く）
##   showcase: bool（数枚から 1 枚を選ぶとき、StS2 の「Choose a Card」の見た目 = CardShowcase で出す。1 枚選び・SHOWCASE_MAX 枚以下のときだけ効く）
##   dim: bool（showcase の暗幕。既定 true）、fly_to: Vector2（showcase で選んだカードが飛んでいく先。既定 INF = 飛ばない）
## max_count == min_count == 1 のときはクリックした時点で決定する。
## upgrade_preview なら、クリックで「前 → 後」の比較を出し、「決定」で確定・「戻る」/ Esc で一覧に戻る（GameDesign §12.5、U14）。

signal picked(indices: PackedInt32Array)

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/widgets/card_view.tscn")
const COMPARE_SCALE: float = 1.3
## 3 択の見た目（showcase）で出せる枚数の上限（横 1 列に収まる数）。超えたら一覧で出す。
const SHOWCASE_MAX: int = 5

var min_count: int = 0
var max_count: int = 0
var upgrade_preview: bool = false
## 比較を出しているカードの番号（-1 = 出していない）。
var comparing: int = -1
## 3 択の見た目で出しているとき（null = 一覧）。
var showcase: CardShowcase
var _fly_to: Vector2 = Vector2.INF
var _entries: Array = []
var _views: Array[CardView] = []
var _selected: Array[int] = []

@onready var _title: Label = %Title
@onready var _info: Label = %Info
@onready var _grid: GridContainer = %Grid
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton
@onready var _compare: Control = %Compare
@onready var _list: Control = $Margin
@onready var _before_slot: Control = %BeforeSlot
@onready var _after_slot: Control = %AfterSlot


func enter(args: Dictionary) -> void:
	_title.text = args.get(&"title", "")
	_info.text = args.get(&"info", "")
	_info.visible = not _info.text.is_empty()
	min_count = args.get(&"min_count", 0)
	max_count = args.get(&"max_count", 0)
	cancellable = args.get(&"cancellable", true)
	_cancel.text = args.get(&"cancel_text", "閉じる")
	_cancel.visible = cancellable
	_confirm.text = args.get(&"confirm_text", "決定")
	_confirm.visible = max_count > 0 and not _instant_pick()
	_confirm.pressed.connect(_on_confirm_pressed)
	_cancel.pressed.connect(cancel)
	(%BackButton as Button).pressed.connect(close_compare)
	(%CompareConfirmButton as Button).pressed.connect(confirm_compare)
	var entries: Array = args.get(&"entries", [])
	_entries = entries
	upgrade_preview = args.get(&"upgrade_preview", false) and _instant_pick()
	_fly_to = args.get(&"fly_to", Vector2.INF)
	var use_showcase: bool = args.get(&"showcase", false) and _instant_pick() and not upgrade_preview \
			and entries.size() >= 1 and entries.size() <= SHOWCASE_MAX
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var view := CARD_VIEW_SCENE.instantiate() as CardView
		if not use_showcase:
			_grid.add_child(view)
		view.show_card(entry[&"data"], entry.get(&"text", ""), entry.get(&"card"), entry.get(&"cost", -1))
		view.pressed.connect(_on_card_pressed.bind(i))
		_views.append(view)
	if use_showcase:
		_open_showcase(args)
	if entries.is_empty():
		_info.text = "（カードがありません）"
		_info.visible = true
	_refresh()


## 3 択の見た目（CardShowcase）で出す。一覧のパネルは隠し、暗幕は dim = false なら出さない（報酬画面が暗くしてある）。
func _open_showcase(args: Dictionary) -> void:
	_list.visible = false
	var dim := $Dim as Control
	dim.visible = args.get(&"dim", true)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)
	showcase = CardShowcase.new()
	add_child(showcase)
	move_child(showcase, dim.get_index() + 1)
	showcase.setup(_title.text, _info.text, _entries, _views, cancellable, _cancel.text)
	showcase.skip_pressed.connect(cancel)
	showcase.play_enter()


## 戦闘外のカード（デッキ）の entries。
static func entries_of_cards(cards: Array) -> Array:
	var entries: Array = []
	for c: Card in cards:
		entries.append({data = c.data, text = UiText.card_text(c.data, c), card = c})
	return entries


static func entries_of_data(list: Array) -> Array:
	var entries: Array = []
	for d: CardData in list:
		entries.append({data = d, text = UiText.card_text(d)})
	return entries


## 名前順（山札の閲覧で順番を伏せる。GameDesign §5.7 の回答）。
static func sorted_by_name(cards: Array[Card]) -> Array[Card]:
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a: Card, b: Card) -> bool:
		return a.data.name < b.data.name if a.data.name != b.data.name else a.uid < b.uid)
	return sorted


## テストと自動操作用：選択して決定する（クリックと同じ経路）。
func choose(indices: PackedInt32Array) -> bool:
	_selected.clear()
	for i in indices:
		if i < 0 or i >= _views.size() or _selected.has(i):
			return false
		_selected.append(i)
	if not _can_confirm():
		return false
	_finish()
	return true


func card_count() -> int:
	return _views.size()


## アップグレードの比較を出す（クリックと同じ経路）。
func open_compare(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var data: CardData = _entries[index][&"data"]
	if data.upgraded == null:
		return
	comparing = index
	var before_text: String = _entries[index].get(&"text", UiText.card_text(data))
	_fill_slot(_before_slot, data, before_text)
	_fill_slot(_after_slot, data.upgraded, UiText.card_text(data.upgraded))
	_compare.visible = true
	_list.visible = false


func close_compare() -> void:
	comparing = -1
	_compare.visible = false
	_list.visible = true
	_clear_slot(_before_slot)
	_clear_slot(_after_slot)


## 比較中のカードで決定する。
func confirm_compare() -> void:
	if comparing < 0:
		return
	_selected = [comparing]
	close_compare()
	_finish()


## Esc / キャンセル：比較中なら一覧に戻るだけ（キャンセル不可のパネルでも戻れる）。
func cancel() -> void:
	if comparing >= 0:
		close_compare()
		return
	super.cancel()


func _clear_slot(slot: Control) -> void:
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()


func _fill_slot(slot: Control, data: CardData, text: String) -> void:
	_clear_slot(slot)
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	slot.add_child(view)
	view.show_card(data, text)
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2.ONE * COMPARE_SCALE


func _instant_pick() -> bool:
	return max_count == 1 and min_count == 1


func _can_confirm() -> bool:
	return max_count > 0 and _selected.size() >= min_count and _selected.size() <= max_count


func _on_card_pressed(_view: CardView, index: int) -> void:
	if max_count <= 0:
		return
	if showcase != null:
		# ほかのカードが消えてから決定する（選んだカードはデッキへ飛び続ける）
		if not showcase.is_picking():
			showcase.play_pick(index, _fly_to, choose.bind(PackedInt32Array([index])))
		return
	if upgrade_preview:
		open_compare(index)
		return
	if _instant_pick():
		_selected = [index]
		_finish()
		return
	if _selected.has(index):
		_selected.erase(index)
	elif _selected.size() < max_count:
		_selected.append(index)
	_refresh()


func _on_confirm_pressed() -> void:
	if _can_confirm():
		_finish()


func _finish() -> void:
	var result := PackedInt32Array(_selected)
	result.sort()
	picked.emit(result)
	close()


func _refresh() -> void:
	for i in _views.size():
		_views[i].set_selected(_selected.has(i))
	_confirm.disabled = not _can_confirm()
	if max_count > 1 or (max_count == 1 and min_count == 0):
		_confirm.text = "決定（%d / %d）" % [_selected.size(), max_count]

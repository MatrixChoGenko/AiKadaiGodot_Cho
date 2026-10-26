class_name ShopScreen extends PanelScreen
## ⑤ Presentation：ショップ（GameDesign §12.3 / §15.6、U12）。3 段でちょうど 1 画面、スクロールなし：
##   1 段目：カード 5 枚（カード面 ＋ 価格）
##   2 段目：レリック 2 つ ＋ ポーション 3 本（アイコン ＋ 名前 ＋ 価格。ホバーで説明）
##   3 段目：カード削除 / アップグレードのサービス（カード選択パネルを開く。アップグレードは前後の比較つき）
## 商品はクリックで買う。買うとすぐにゴールドが減って「売り切れ」になる。足りない商品は価格を赤にして暗くする。
## ポーション枠がいっぱいのとき・ゴールドが足りないときは案内を出す。

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/widgets/card_view.tscn")
const CARD_SCALE: float = 1.0
const ICON_SIZE: Vector2 = Vector2(100, 100)
const COIN_SIZE: Vector2 = Vector2(26, 26)
const SERVICE_SIZE: Vector2 = Vector2(360, 84)
const PRICE_COLOR: Color = Color(1, 0.85, 0.35)
const PRICE_SHORT_COLOR: Color = Color(1, 0.42, 0.38)
const SOLD_COLOR: Color = Color(0.6, 0.6, 0.6)
const SOLD_ALPHA: float = 0.25
const DIM_ALPHA: float = 0.55
const HOVER_OUTLINE: Color = Color(1, 0.9, 0.5)
const HOVER_BRIGHT: Color = Color(1.3, 1.25, 1.15)
const COIN_COLOR: Color = Color(0.85, 0.65, 0.15)

## 商品の番号 → 表示（テスト用。カードは CardView、レリック / ポーションは GlyphBadge）。
var offer_views: Dictionary[int, Control] = {}
## 商品の番号 → 価格の Label。
var price_labels: Dictionary[int, Label] = {}
var removal_button: Button
var upgrade_button: Button


func _init() -> void:
	panel_width = 1560.0


func enter(args: Dictionary) -> void:
	super.enter(args)
	title_label.text = "ショップ"
	rebuild()


func rebuild() -> void:
	clear_body()
	clear_footer()
	offer_views.clear()
	price_labels.clear()
	var stock := Party.me(run).shop
	var cards := _row(18)
	var goods := _row(56)
	var relics := _row(28, goods)
	var potions := _row(28, goods)
	if stock != null:
		for i in stock.items.size():
			var item := stock.items[i]
			match item.kind:
				ShopItem.Kind.CARD:
					cards.add_child(_card_offer(i, item))
				ShopItem.Kind.RELIC:
					relics.add_child(_icon_offer(i, item))
				ShopItem.Kind.POTION:
					potions.add_child(_icon_offer(i, item))
	var services := _row(40)
	removal_button = _service_button("カード削除", run.removal_price(Party.seat()), open_removal, services,
			"カード削除\nデッキからカードを 1 枚取り除く。使うたびに価格が %d 上がる。" % run.config.removal_price_step)
	removal_button.disabled = Party.me(run).deck.size() == 0
	upgrade_button = _service_button("アップグレード", run.upgrade_price(Party.seat()), open_upgrade, services,
			"アップグレード\nデッキのカードを 1 枚アップグレードする。使うたびに価格が %d 上がる。" % run.config.upgrade_price_step)
	upgrade_button.disabled = Party.me(run).deck.upgradable().is_empty()
	add_button(UiText.WAITING_FOR_PARTY + "（取り消す）" if Party.coop() and Party.me(run).done else "ショップを出る",
			leave, footer, &"ButtonPrimary")


## i 番目の商品を買う（クリックと同じ経路）。
func buy(index: int) -> void:
	var item := Party.me(run).shop.item(index) if Party.me(run).shop != null else null
	if item == null or item.sold:
		return
	if item.kind == ShopItem.Kind.POTION and Party.me(run).potions.is_full():
		notice("ポーション枠がいっぱいです")
		return
	if Party.me(run).gold < item.price:
		notice("ゴールドが足りません")
		return
	Party.act(run, CoopCommands.BUY, {item = index}, _on_bought)


func _on_bought(ok: bool) -> void:
	if ok and is_inside_tree():
		rebuild()
		run_changed.emit()


func open_removal() -> void:
	if not _can_afford(run.removal_price(Party.seat())):
		return
	var modal := open_card_list({title = "削除するカードを選ぶ（%d G）" % run.removal_price(Party.seat()),
			entries = CardListModal.entries_of_cards(Party.me(run).deck.cards), min_count = 1, max_count = 1, cancel_text = "やめる"})
	if modal != null:
		modal.picked.connect(_on_removal_picked.bind(Party.me(run).deck.cards.duplicate()))


func open_upgrade() -> void:
	if not _can_afford(run.upgrade_price(Party.seat())):
		return
	var candidates := Party.me(run).deck.upgradable()
	var modal := open_card_list({title = "アップグレードするカードを選ぶ（%d G）" % run.upgrade_price(Party.seat()),
			entries = CardListModal.entries_of_cards(candidates), min_count = 1, max_count = 1, cancel_text = "やめる",
			upgrade_preview = true})
	if modal != null:
		modal.picked.connect(_on_upgrade_picked.bind(candidates))


## ショップを出る。協力プレイでは全員が出るまで待つ（もう一度押すと取り消し）。
func leave() -> void:
	var op := CoopCommands.CANCEL_LEAVE if Party.coop() and Party.me(run).done else CoopCommands.LEAVE
	Party.act(run, op, {}, _on_leave_changed)


func _on_leave_changed(ok: bool) -> void:
	if ok and is_inside_tree() and run.state.phase == RunPhase.Id.SHOP:
		rebuild()


func _can_afford(price: int) -> bool:
	if Party.me(run).gold >= price:
		return true
	notice("ゴールドが足りません")
	return false


func _row(separation: int, parent: Container = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", separation)
	(parent if parent != null else body).add_child(row)
	return row


func _card_offer(index: int, item: ShopItem) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	var holder := Control.new()
	holder.custom_minimum_size = CardView.BASE_SIZE * CARD_SCALE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	var view := CARD_VIEW_SCENE.instantiate() as CardView
	holder.add_child(view)
	view.show_card(item.card, UiText.card_text(item.card))
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2.ONE * CARD_SCALE
	if item.sold:
		view.modulate.a = SOLD_ALPHA
		view.tips_enabled = false
	else:
		view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		view.pressed.connect(func(_v: CardView) -> void: buy(index))
		view.hover_changed.connect(func(v: CardView, on: bool) -> void: v.set_playable(on and run.can_buy(index, Party.seat())))
		if not run.can_buy(index, Party.seat()):
			view.modulate.a = DIM_ALPHA
	offer_views[index] = view
	column.add_child(_price_row(index, item))
	return column


func _icon_offer(index: int, item: ShopItem) -> Control:
	var is_relic := item.kind == ShopItem.Kind.RELIC
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.custom_minimum_size = Vector2(150, 0)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(center)
	var badge := GlyphBadge.new()
	badge.custom_minimum_size = ICON_SIZE
	var item_name: String
	if is_relic:
		item_name = item.relic.name
		badge.setup(UiGlyphs.first_char(item_name), UiGlyphs.RELIC_COLORS.get(item.relic.rarity, Color.GRAY), GlyphBadge.Shape.ROUNDED)
		badge.tooltip_text = UiText.relic_text(item.relic)
		badge.icon = UiGlyphs.relic_icon(item.relic)
	else:
		item_name = item.potion.name
		badge.setup(UiGlyphs.first_char(item_name), UiGlyphs.POTION_COLORS.get(item.potion.rarity, Color.GRAY), GlyphBadge.Shape.DIAMOND)
		badge.tooltip_text = UiText.potion_text(item.potion)
		badge.icon = UiGlyphs.potion_icon(item.potion)
	if badge.icon != null:
		badge.outline_width = 0.0
		badge.icon_ratio = 0.9
	center.add_child(badge)
	var label := Label.new()
	label.text = item_name
	label.theme_type_variation = &"LabelSmall"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	if item.sold:
		column.modulate.a = SOLD_ALPHA
	else:
		badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		badge.gui_input.connect(_on_icon_gui_input.bind(index))
		# 画像は縁取りが無いので明るくする（図形は縁取りの色を変える）。
		badge.mouse_entered.connect(func() -> void:
			badge.outline = HOVER_OUTLINE
			badge.self_modulate = HOVER_BRIGHT)
		badge.mouse_exited.connect(func() -> void:
			badge.outline = Color(0, 0, 0, 0.8)
			badge.self_modulate = Color.WHITE)
		if not run.can_buy(index, Party.seat()):
			center.modulate.a = DIM_ALPHA
	offer_views[index] = badge
	column.add_child(_price_row(index, item))
	return column


func _price_row(index: int, item: ShopItem) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 6)
	var label := Label.new()
	if item.sold:
		label.text = "売り切れ"
		label.add_theme_color_override(&"font_color", SOLD_COLOR)
	else:
		row.add_child(_coin())
		label.text = str(item.price)
		label.add_theme_color_override(&"font_color", PRICE_COLOR if Party.me(run).gold >= item.price else PRICE_SHORT_COLOR)
	row.add_child(label)
	price_labels[index] = label
	return row


func _service_button(text: String, price: int, on_pressed: Callable, parent: Container, tip: String) -> Button:
	var b := add_button("%s　%d G" % [text, price], on_pressed, parent)
	b.custom_minimum_size = SERVICE_SIZE
	b.tooltip_text = tip
	if Party.me(run).gold < price:
		b.add_theme_color_override(&"font_color", PRICE_SHORT_COLOR)
	return b


func _coin() -> GlyphBadge:
	var coin := GlyphBadge.new()
	coin.custom_minimum_size = COIN_SIZE
	coin.outline_width = 2.0
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coin.setup("G", COIN_COLOR)


func _on_icon_gui_input(event: InputEvent, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		buy(index)


func _on_removal_picked(indices: PackedInt32Array, candidates: Array[Card]) -> void:
	if not indices.is_empty():
		Party.act(run, CoopCommands.BUY_REMOVAL, {card = candidates[indices[0]].uid}, _on_bought)


func _on_upgrade_picked(indices: PackedInt32Array, candidates: Array[Card]) -> void:
	if not indices.is_empty():
		Party.act(run, CoopCommands.BUY_UPGRADE, {card = candidates[indices[0]].uid}, _on_bought)

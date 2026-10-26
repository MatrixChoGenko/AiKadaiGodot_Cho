class_name RewardScreen extends Screen
## ⑤ Presentation：戦闘報酬 / 宝箱（GameDesign §12.1 / §12.2 / §15.5、U08）。StS2 の「Loot!」に合わせた見た目と演出。
## - 戦闘の後は、暗くした戦場（ScreenHost が残した戦闘画面）の上に出す。再起動から再開したときは戦闘の背景画像を自前で出す。
## - 宝箱のマスは、まず宝箱の部屋（TreasureChestView）だけを見せ、宝箱をクリックして開けると暗くなってパネルが出る。
## - 青い石のパネルに報酬を 1 行ずつ並べ、上辺に羊皮紙のリボン。受け取った行は縮んで消え、下の行が詰まる。
## - カードの行はカードの 3 択（CardListModal の showcase）を開き、その間パネルは隠す。スキップしたら行は残る。
## - 右下の赤い矢印でマップへ戻る（受け取っていない行があれば「スキップ」、無ければ「進む」。受け取らなかった報酬は失われる）。

const PANEL: Texture2D = preload("res://assets/textures/ui/reward/panel.png")
const RIBBON: Texture2D = preload("res://assets/textures/ui/reward/ribbon.png")
const ICON_GOLD: Texture2D = preload("res://assets/textures/ui/hud/coin.png")
const ICON_CARD: Texture2D = preload("res://assets/textures/ui/reward/icon_card.png")
const ICON_RELIC: Texture2D = preload("res://assets/textures/ui/reward/icon_relic.png")
const ICON_POTION: Texture2D = preload("res://assets/textures/ui/reward/icon_potion.png")
const FONT: Font = preload("res://assets/fonts/banner_mincho.ttf")

## 背景を暗くする強さ（StS2 の録画では戦場がかなり沈む）。
const DIM_ALPHA: float = 0.72
const PANEL_SIZE: Vector2 = Vector2(560, 640)
## パネルの中心の高さ（画面の高さに対する割合）とリボンの縮尺。
const PANEL_Y: float = 0.56
const RIBBON_SCALE: float = 0.72
## 入ってくる演出の秒数。
const ENTER_TIME: float = 0.3
const ROW_STAGGER: float = 0.06

## i 行目（pending_reward.items の番号）→ 表示中の行。受け取った行は消す。
var rows: Dictionary[int, RewardRow] = {}
var proceed_button: ProceedArrow
## 宝箱の部屋（宝箱のマスのときだけ。戦闘報酬では null）。
var chest: TreasureChestView

var _dim: ColorRect
var _loot: Control
var _list: VBoxContainer
var _ribbon_label: Label
var _notice: Label
var _lift: float = 0.0


func enter(args: Dictionary) -> void:
	super.enter(args)
	var treasure := run.state.phase == RunPhase.Id.TREASURE
	if treasure:
		chest = TreasureChestView.new()
		add_child(chest)
	elif not args.get(&"battle_behind", false):
		_add_battle_backdrop()
	_build()
	_ribbon_label.text = "宝箱" if treasure else "戦利品"
	_sync_rows(false)
	if chest == null:
		_play_enter()
		return
	# 宝箱：まず宝箱だけを見せ、開けたら戦利品のパネル。何か受け取り済み（再起動から再開）なら開いた状態から
	chest.opened.connect(_on_chest_opened)
	_loot.visible = false
	_dim.modulate.a = 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proceed_button.slide_in(0.3)
	for item in Party.me(run).pending_reward.items:
		if item.taken:
			chest.open(false)
			break


## i 行目を受け取る（カードは 3 択を開く）。クリックと同じ経路。
func take(i: int) -> void:
	var item := Party.me(run).pending_reward.item(i)
	if item == null or item.taken:
		return
	if chest != null and not chest.is_open:
		chest.open(false)
	if item.kind == RewardItem.Kind.CARDS:
		var modal := open_card_list({title = "カードを選ぶ", entries = CardListModal.entries_of_data(item.cards),
				min_count = 1, max_count = 1, cancel_text = "スキップ", showcase = true, dim = false,
				fly_to = top_bar.deck_center() if top_bar != null else Vector2.INF})
		if modal != null:
			modal.picked.connect(_on_card_picked.bind(i))
			modal.closed.connect(_show_loot)
			_hide_loot()
		return
	Party.act(run, CoopCommands.TAKE_REWARD, {item = i}, _on_taken.bind(item.kind))


func _on_taken(ok: bool, kind: RewardItem.Kind) -> void:
	if not ok:
		if kind == RewardItem.Kind.POTION:
			notice("ポーション枠がいっぱいです（トップバーのポーションを捨ててから受け取れます）")
		return
	_sync_rows(true)
	run_changed.emit()


## 先へ進む。協力プレイでは全員が押すまで待つ（もう一度押すと取り消し）。
func leave() -> void:
	if Party.coop() and Party.me(run).done:
		Party.act(run, CoopCommands.CANCEL_LEAVE, {}, _on_leave_changed)
	else:
		Party.act(run, CoopCommands.LEAVE, {}, _on_leave_changed)


func _on_leave_changed(_ok: bool) -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_sync_rows(false)


## 受け取っていない行があるか（矢印の文言）。
func has_untaken() -> bool:
	var reward := Party.me(run).pending_reward
	if reward == null:
		return false
	for item in reward.items:
		if not item.taken:
			return true
	return false


## 画面内の案内（ポーション枠がいっぱい…）。パネルの下に出して消す。
func notice(text: String) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	var t := _notice.create_tween()
	t.tween_interval(2.0)
	t.tween_property(_notice, "modulate:a", 0.0, 0.3)


func _on_card_picked(indices: PackedInt32Array, item_index: int) -> void:
	if not indices.is_empty():
		Party.act(run, CoopCommands.TAKE_REWARD, {item = item_index, card = indices[0]}, _on_card_taken)


func _on_card_taken(ok: bool) -> void:
	if ok:
		_sync_rows(false)
		run_changed.emit()


## 行を報酬の状態に合わせる。受け取った行は animate なら縮んで消え、そうでなければすぐ消す。
func _sync_rows(animate: bool) -> void:
	var reward := Party.me(run).pending_reward
	var items: Array = reward.items if reward != null else []
	for i in items.size():
		var item: RewardItem = items[i]
		if item.taken and rows.has(i):
			if animate:
				rows[i].play_remove()
			else:
				_list.remove_child(rows[i])
				rows[i].queue_free()
			rows.erase(i)
		elif not item.taken and not rows.has(i):
			var row := RewardRow.new(_label_of(item), _icon_of(item))
			row.tooltip_text = _tooltip_of(item)
			row.pressed.connect(take.bind(i))
			_list.add_child(row)
			rows[i] = row
	proceed_button.set_label(UiText.WAITING_FOR_PARTY if Party.coop() and Party.me(run).done
			else "スキップ" if has_untaken() else "進む")


func _label_of(item: RewardItem) -> String:
	match item.kind:
		RewardItem.Kind.GOLD:
			return "%d ゴールド" % item.gold
		RewardItem.Kind.CARDS:
			return "カードをデッキに加える"
		RewardItem.Kind.RELIC:
			return item.relic.name
		RewardItem.Kind.POTION:
			return item.potion.name
	return ""


func _icon_of(item: RewardItem) -> Texture2D:
	match item.kind:
		RewardItem.Kind.GOLD:
			return ICON_GOLD
		RewardItem.Kind.CARDS:
			return ICON_CARD
		RewardItem.Kind.RELIC:
			var relic_icon := UiGlyphs.relic_icon(item.relic)
			return relic_icon if relic_icon != null else ICON_RELIC
	var potion_icon := UiGlyphs.potion_icon(item.potion)
	return potion_icon if potion_icon != null else ICON_POTION


func _tooltip_of(item: RewardItem) -> String:
	match item.kind:
		RewardItem.Kind.RELIC:
			return UiText.relic_text(item.relic)
		RewardItem.Kind.POTION:
			return UiText.potion_text(item.potion)
	return ""


# —— 組み立て ——

## 再起動から報酬で再開したとき：戦闘と同じ背景画像（同じシード・マスなら同じ絵）。
func _add_battle_backdrop() -> void:
	var data := load(CombatScreen.BACKDROPS[CombatScreen.backdrop_index_of(run)]) as BackdropData
	var bg := TextureRect.new()
	bg.texture = data.texture
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build() -> void:
	# 暗幕：後ろの戦場への入力も止める
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, DIM_ALPHA)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_loot = Control.new()
	_loot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot.size = PANEL_SIZE
	_loot.pivot_offset = PANEL_SIZE / 2.0
	add_child(_loot)
	var panel := TextureRect.new()
	panel.texture = PANEL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot.add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 14)
	_list.position = Vector2((PANEL_SIZE.x - RewardRow.SIZE.x) / 2.0, 74)
	_list.size = Vector2(RewardRow.SIZE.x, PANEL_SIZE.y - 120)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot.add_child(_list)
	var ribbon := TextureRect.new()
	ribbon.texture = RIBBON
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.size = RIBBON.get_size()
	ribbon.scale = Vector2.ONE * RIBBON_SCALE
	ribbon.position = Vector2((PANEL_SIZE.x - RIBBON.get_size().x * RIBBON_SCALE) / 2.0, -RIBBON.get_size().y * RIBBON_SCALE * 0.62)
	_loot.add_child(ribbon)
	_ribbon_label = _banner_label(54)
	_ribbon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ribbon_label.offset_bottom = -RIBBON.get_size().y * 0.18
	ribbon.add_child(_ribbon_label)
	proceed_button = ProceedArrow.new()
	proceed_button.pressed.connect(leave)
	add_child(proceed_button)
	_notice = Label.new()
	_notice.theme_type_variation = &"LabelSmall"
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.55))
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.modulate.a = 0.0
	add_child(_notice)
	resized.connect(_layout)
	_layout()


func _banner_label(font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", Color(1.0, 0.97, 0.88))
	l.add_theme_constant_override(&"outline_size", 10)
	l.add_theme_color_override(&"font_outline_color", Color(0.22, 0.12, 0.06))
	return l


## 置き場所は画面の大きさから決める（入ってくる演出のずれ _lift もここで足す。大きさが後から決まっても崩れない）。
func _layout() -> void:
	var s := size
	var home := Vector2(s.x / 2.0, s.y * PANEL_Y) - PANEL_SIZE / 2.0
	_loot.position = home + Vector2(0, _lift)
	_notice.position = Vector2(0, home.y + PANEL_SIZE.y + 16.0)
	_notice.size = Vector2(s.x, 40)


func _set_lift(v: float) -> void:
	_lift = v
	_layout()


# —— 演出 ——

## 宝箱が開いた：暗幕を入力を止める側に戻し、戦利品のパネルを出す（矢印はもう出ている）。
func _on_chest_opened() -> void:
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_loot.visible = true
	_play_enter(false)


## 入ってくる：暗転 → パネルが少し上から落ちてくる → 行が順に出る → 矢印が右から滑り込む（with_arrow）。
func _play_enter(with_arrow: bool = true) -> void:
	_dim.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_dim, "modulate:a", 1.0, ENTER_TIME)
	_set_lift(-40.0)
	_loot.modulate.a = 0.0
	t.tween_method(_set_lift, -40.0, 0.0, ENTER_TIME).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_loot, "modulate:a", 1.0, ENTER_TIME * 0.6).set_delay(0.08)
	var k := 0
	for i in rows:
		rows[i].play_enter(0.22 + k * ROW_STAGGER)
		k += 1
	if with_arrow:
		proceed_button.slide_in(0.3)


## カードの 3 択を開いた：パネルはすぐ消し、矢印はフェードで消す（StS2 の録画で 1 フレームで消えていた）。
func _hide_loot() -> void:
	_loot.visible = false
	proceed_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(proceed_button, "modulate:a", 0.0, 0.1)


## 3 択を閉じた（選んだ / スキップ）：パネルを素早く戻す。
func _show_loot() -> void:
	_loot.visible = true
	_loot.modulate.a = 0.0
	_loot.scale = Vector2.ONE * 0.96
	proceed_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween().set_parallel(true)
	t.tween_property(_loot, "modulate:a", 1.0, 0.15)
	t.tween_property(_loot, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(proceed_button, "modulate:a", 1.0, 0.15)

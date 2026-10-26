class_name EventScreen extends Screen
## ⑤ Presentation：ランダムイベント（GameDesign §12.4 / §15.7、U13）。StS2 のイベント画面に合わせた見た目。
## 左は背景の絵（event_chamber。イベントごとの挿絵は無し = 付録 C の C55）、右は暗くした上に見出し（金）・本文・選択肢の帯を縦に並べる。
## 選択肢（条件を満たさなければ灰色 + 理由）→ 結果の文 → カード選択のリクエストを 1 つずつ処理（キャンセル不可）→「続ける」。
## 「続ける」は run.leave_node()。イベントが戦闘を予約していれば、そのまま戦闘へ進む（RunController が決める）。

const BACKDROP: Texture2D = preload("res://assets/textures/backgrounds/event_chamber.jpg")
const FONT: Font = preload("res://assets/fonts/banner_mincho.ttf")
## 右の列の横の範囲（画面の幅に対する割合）と上端（高さに対する割合）。StS2 の録画で 0.48〜0.9。
const COLUMN_LEFT: float = 0.5
const COLUMN_RIGHT: float = 0.92
const COLUMN_TOP: float = 0.19
## 右側を暗くするグラデーション：[横の位置, 暗さ]。
const SHADE: Array = [[0.0, 0.0], [0.36, 0.0], [0.6, 0.8], [1.0, 0.88]]
const SHADE_COLOR: Color = Color(0.02, 0.035, 0.05)
const TITLE_COLOR: Color = Color(0.96, 0.79, 0.38)
## 入ってくる演出：見出し・本文のフェードの秒数、選択肢が右から滑り込む量と 1 つずつの遅れ。
const FADE_TIME: float = 0.3
const OPTION_SLIDE: float = 48.0
const OPTION_STAGGER: float = 0.07

## 表示中の選択肢の帯（選ぶ前 = イベントの選択肢の順。選んだ後 = 「カードを選ぶ」か「続ける」の 1 つ）。
var option_buttons: Array[EventOptionButton] = []

var _result_text: String = ""
var _title: Label
var _body: RichTextLabel
var _options: VBoxContainer
var _enter_tween: Tween


func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = BACKDROP
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := TextureRect.new()
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.anchor_left = COLUMN_LEFT
	column.anchor_right = COLUMN_RIGHT
	column.anchor_top = COLUMN_TOP
	column.anchor_bottom = 0.97
	column.add_theme_constant_override(&"separation", 26)
	add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override(&"font", FONT)
	_title.add_theme_font_size_override(&"font_size", 46)
	_title.add_theme_color_override(&"font_color", TITLE_COLOR)
	_title.add_theme_constant_override(&"outline_size", 8)
	_title.add_theme_color_override(&"font_outline_color", Color(0.1, 0.06, 0.02))
	column.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_size_override(&"normal_font_size", 25)
	_body.add_theme_constant_override(&"line_separation", 8)
	_body.add_theme_constant_override(&"outline_size", 4)
	_body.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.6))
	column.add_child(_body)
	var gap := Control.new()
	gap.custom_minimum_size.y = 40
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	_options = VBoxContainer.new()
	_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options.add_theme_constant_override(&"separation", 14)
	column.add_child(_options)


func enter(args: Dictionary) -> void:
	super.enter(args)
	var ev := run.state.event
	_title.text = ev.title if ev != null else "イベント"
	rebuild()


func rebuild() -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	option_buttons.clear()
	var ev := run.state.event
	if ev == null:
		_set_body("")
		_add_option("続ける", "", leave)
		_play_enter()
		return
	if Party.me(run).event_choice < 0:
		_set_body(ev.body)
		for i in ev.options.size():
			var option := ev.options[i]
			_add_option(option.text, UiText.event_detail_markup(option.detail), choose.bind(i),
					option.disabled_hint, run.event_option_available(i, Party.seat()))
	else:
		_set_body(_result_text if not _result_text.is_empty() else ev.options[Party.me(run).event_choice].result_text)
		if run.pending_request(Party.seat()) != null:
			_add_option("カードを選ぶ", "", open_request)
		elif Party.coop() and Party.me(run).done:
			_add_option(UiText.WAITING_FOR_PARTY, "ほかの人を待っています（押すと取り消し）", leave)
		else:
			_add_option("続ける", "", leave)
	_play_enter()


## 選択肢を選ぶ（クリックと同じ経路）。
func choose(index: int) -> void:
	Party.act(run, CoopCommands.EVENT_OPTION, {option = index}, _on_chosen.bind(index))


func _on_chosen(ok: bool, index: int) -> void:
	if not ok or not is_inside_tree() or run.state.event == null:
		return
	_result_text = run.state.event.options[index].result_text
	rebuild()
	run_changed.emit()
	open_request()


## 先頭のカード選択リクエストのパネルを開く（無ければ何もしない）。
func open_request() -> void:
	var req := run.pending_request(Party.seat())
	if req == null or (modals != null and not modals.is_empty()):
		return
	var candidates := run.request_candidates(Party.seat())
	var entries := CardListModal.entries_of_data(candidates) if req.kind == RunChoiceRequest.Kind.PICK \
			else CardListModal.entries_of_cards(candidates)
	var n := run.request_pick_count(Party.seat())
	var modal := open_card_list({title = UiText.REQUEST_PROMPTS.get(req.kind, "カードを選ぶ"), info = "%d 枚選ぶ" % n,
			entries = entries, min_count = n, max_count = n, cancellable = false,
			upgrade_preview = req.kind == RunChoiceRequest.Kind.UPGRADE,
			# 生成した候補から 1 枚もらう：報酬と同じ 3 択の見た目で、選んだカードはデッキへ飛ぶ
			showcase = req.kind == RunChoiceRequest.Kind.PICK,
			fly_to = top_bar.deck_center() if top_bar != null else Vector2.INF})
	if modal != null:
		modal.picked.connect(_on_request_picked)


## 先へ進む。協力プレイでは全員が押すまで待つ（もう一度押すと取り消し）。
func leave() -> void:
	var op := CoopCommands.CANCEL_LEAVE if Party.coop() and Party.me(run).done else CoopCommands.LEAVE
	Party.act(run, op, {}, _on_leave_changed)


func _on_leave_changed(ok: bool) -> void:
	if ok and is_inside_tree() and run.state.phase == RunPhase.Id.EVENT:
		rebuild()


func _on_request_picked(indices: PackedInt32Array) -> void:
	Party.act(run, CoopCommands.RESOLVE_REQUEST, {indices = Array(indices)}, _on_request_resolved)


func _on_request_resolved(ok: bool) -> void:
	if not ok:
		Log.warn(&"run", "event card choice was rejected")
	if not is_inside_tree():
		return
	rebuild()
	run_changed.emit()
	open_request.call_deferred()


func _set_body(text: String) -> void:
	_body.text = "[center]%s[/center]" % text
	_body.visible = not text.is_empty()


## 帯は MarginContainer（入れ物）の中に置く。大きさはコンテナに任せ（折り返しのある文の高さが正しく決まる）、
## 滑り込みは入れ物の左右の余白を同じだけずらして表す（_set_slide）。
func _add_option(title: String, detail: String, on_pressed: Callable, hint: String = "", enabled: bool = true) -> void:
	var holder := MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options.add_child(holder)
	var b := EventOptionButton.new(title, detail, hint, enabled)
	b.pressed.connect(on_pressed)
	holder.add_child(b)
	option_buttons.append(b)


static func _set_slide(x: float, holder: MarginContainer) -> void:
	holder.add_theme_constant_override(&"margin_left", roundi(x))
	holder.add_theme_constant_override(&"margin_right", -roundi(x))


# —— 演出 ——

## 見出しと本文はフェードで、選択肢は 1 つずつ右から滑り込む。
func _play_enter() -> void:
	# 作り直した直後なので、前の演出（消した帯の入れ物を動かしている）は止める
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	var t := create_tween().set_parallel(true)
	_enter_tween = t
	for c: Control in [_title, _body]:
		c.modulate.a = 0.0
		t.tween_property(c, "modulate:a", 1.0, FADE_TIME)
	for i in option_buttons.size():
		var b := option_buttons[i]
		var delay := 0.12 + i * OPTION_STAGGER
		var holder := b.get_parent() as MarginContainer
		b.modulate.a = 0.0
		_set_slide(OPTION_SLIDE, holder)
		t.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(delay)
		t.tween_method(_set_slide.bind(holder), OPTION_SLIDE, 0.0, 0.28).set_delay(delay) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _shade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(SHADE.map(func(p: Array) -> float: return p[0]))
	g.colors = PackedColorArray(SHADE.map(func(p: Array) -> Color: return Color(SHADE_COLOR, p[1])))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 4
	return tex

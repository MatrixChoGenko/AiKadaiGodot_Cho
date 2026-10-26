class_name RestScreen extends Screen
## ⑤ Presentation：休憩所（GameDesign §12.5 / §15.8、U14）。StS2 の休憩所に合わせた見た目。
## 「休む」か「鍛える」のどちらかを選ぶ（何もせずには離れられない。付録 C の C32）。
## - 背景の絵（rest_campfire）の焚き火に、揺らぐ炎・周りの光の明滅・火の粉を重ねる（絵の座標で置き、画面の大きさに合わせて写す）。
## - 上に見出し、絵のタイル 2 枚（ホバーで金の縁）、その下にホバー中の選択肢の説明。
## - 「鍛える」はカード選択パネルの比較モード（クリック → 前後の比較 →「決定」）。選んだ後はタイルを消して結果の文を出し、
##   右下の赤い矢印（ProceedArrow）でマップへ。

const BACKDROP: Texture2D = preload("res://assets/textures/backgrounds/rest_campfire.jpg")
const TILE_REST: Texture2D = preload("res://assets/textures/ui/rest/tile_rest.png")
const TILE_SMITH: Texture2D = preload("res://assets/textures/ui/rest/tile_smith.png")
const FONT: Font = preload("res://assets/fonts/banner_mincho.ttf")
const FLAME_SHADER: Shader = preload("res://assets/shaders/campfire_flame.gdshader")
const GLOW_SHADER: Shader = preload("res://assets/shaders/campfire_glow.gdshader")
const EMBER_TEX: Texture2D = preload("res://assets/textures/fx/fx_soft.png")
## 背景の絵（2752x1536）の中の焚き火の位置（絵の px）：炎の矩形・光の矩形・火の粉の出る点。
const FLAME_RECT: Rect2 = Rect2(1295, 862, 170, 216)
const GLOW_RECT: Rect2 = Rect2(1068, 880, 620, 360)
const EMBER_AT: Vector2 = Vector2(1380, 1010)
## 高さの割合：見出し・タイルの中心・説明。タイルの中心どうしの間隔。
const TITLE_Y: float = 0.13
const TILES_Y: float = 0.31
const DESC_Y: float = 0.5
const TILE_GAP: float = 380.0
const HEAL_COLOR: String = "#8ee07a"
## 入ってくるとき、タイルが下からせり上がる量（px）。
const RISE: float = 30.0

## 選択肢のタイル（選んだ後は空）。
var tiles: Array[RestTile] = []
var proceed_button: ProceedArrow

## 直前に選んだ結果の文（画面を作り直すまで）。
var _result: String = ""
var _bg: TextureRect
var _fire: Array[Control] = []   # 炎・光（絵の座標で置く）
var _embers: GPUParticles2D
var _title: Label
var _desc: RichTextLabel
var _tile_row: Control
var _rise: PackedFloat32Array = []
var _enter_tween: Tween


func _ready() -> void:
	_bg = TextureRect.new()
	_bg.texture = BACKDROP
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_fire.append(_shader_rect(GLOW_SHADER))
	_fire.append(_shader_rect(FLAME_SHADER))
	_embers = make_embers()
	add_child(_embers)
	var shade := TextureRect.new()
	shade.texture = _top_shade()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_title = Label.new()
	_title.text = "どうする？"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_override(&"font", FONT)
	_title.add_theme_font_size_override(&"font_size", 50)
	_title.add_theme_color_override(&"font_color", Color(1.0, 0.97, 0.9))
	_title.add_theme_constant_override(&"outline_size", 10)
	_title.add_theme_color_override(&"font_outline_color", Color(0.06, 0.05, 0.04))
	add_child(_title)
	_tile_row = Control.new()
	_tile_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tile_row)
	_desc = RichTextLabel.new()
	_desc.bbcode_enabled = true
	_desc.fit_content = true
	_desc.scroll_active = false
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc.add_theme_font_size_override(&"normal_font_size", 28)
	_desc.add_theme_constant_override(&"outline_size", 6)
	_desc.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_desc)
	proceed_button = ProceedArrow.new()
	proceed_button.pressed.connect(leave)
	proceed_button.visible = false
	add_child(proceed_button)
	resized.connect(_layout)


func enter(args: Dictionary) -> void:
	super.enter(args)
	rebuild()
	_play_enter()


func rebuild() -> void:
	# 入ってくる演出の途中で選んだら、消すタイルを動かしている演出を止める
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	for t in tiles:
		_tile_row.remove_child(t)
		t.queue_free()
	tiles.clear()
	if Party.me(run).rest_used:
		_title.visible = false
		_set_desc(_result if not _result.is_empty() else "一息ついた。")
		if not proceed_button.visible:
			proceed_button.visible = true
			proceed_button.slide_in(0.15)
		_layout()
		return
	_title.visible = true
	_set_desc("")
	var rest_tile := RestTile.new(TILE_REST, "休む")
	rest_tile.pressed.connect(rest)
	rest_tile.hover_changed.connect(_on_tile_hover.bind(0))
	var smith_tile := RestTile.new(TILE_SMITH, "鍛える", run.can_rest_upgrade(Party.seat()))
	smith_tile.pressed.connect(open_upgrade)
	smith_tile.hover_changed.connect(_on_tile_hover.bind(1))
	for t in [rest_tile, smith_tile]:
		_tile_row.add_child(t)
		tiles.append(t)
	_layout()


## 「休む」で回復する量（最大 HP の 30%、0 方向に切り捨て。付録 C の C38。失った分を超えない）。
func heal_amount() -> int:
	var heal := int(Party.me(run).max_hp * run.config.rest_heal_percent / 100.0)
	return mini(heal, Party.me(run).max_hp - Party.me(run).hp)


## タイル i の説明（BBCode）。
func describe(i: int) -> String:
	if i == 0:
		return "HP を [color=%s]%d[/color] 回復する（HP %d/%d）。" % [HEAL_COLOR, heal_amount(), Party.me(run).hp, Party.me(run).max_hp]
	return "カードを 1 枚アップグレードする。" if run.can_rest_upgrade(Party.seat()) else "アップグレードできるカードがない。"


## 説明 / 結果の文（色付けを除く。テスト用）。
func desc_text() -> String:
	return _desc.get_parsed_text()


func rest() -> void:
	var before := Party.me(run).hp
	Party.act(run, CoopCommands.REST_HEAL, {}, _on_rested.bind(before))


func _on_rested(ok: bool, before: int) -> void:
	if not ok or not is_inside_tree():
		return
	_result = "ぐっすり眠った。HP を [color=%s]%d[/color] 回復した。" % [HEAL_COLOR, Party.me(run).hp - before]
	rebuild()
	run_changed.emit()


func open_upgrade() -> void:
	var candidates := Party.me(run).deck.upgradable()
	var modal := open_card_list({title = "アップグレードするカードを選ぶ", entries = CardListModal.entries_of_cards(candidates),
			min_count = 1, max_count = 1, cancel_text = "やめる", upgrade_preview = true})
	if modal != null:
		modal.picked.connect(_on_upgrade_picked.bind(candidates))


## 先へ進む。協力プレイでは全員が押すまで待つ（もう一度押すと取り消し）。
func leave() -> void:
	var op := CoopCommands.CANCEL_LEAVE if Party.coop() and Party.me(run).done else CoopCommands.LEAVE
	Party.act(run, op, {}, _on_leave_changed)


func _on_leave_changed(_ok: bool) -> void:
	if is_inside_tree() and proceed_button != null:
		proceed_button.set_label(UiText.WAITING_FOR_PARTY if Party.coop() and Party.me(run).done else "進む")


func _on_upgrade_picked(indices: PackedInt32Array, candidates: Array[Card]) -> void:
	if indices.is_empty():
		return
	var card := candidates[indices[0]]
	var before := card.data.name
	Party.act(run, CoopCommands.REST_UPGRADE, {card = card.uid}, _on_upgraded.bind(card, before))


func _on_upgraded(ok: bool, card: Card, before: String) -> void:
	if not ok or not is_inside_tree():
		return
	_result = "%s を鍛えて %s にした。" % [before, card.data.name]
	rebuild()
	run_changed.emit()


func _on_tile_hover(hovered: bool, i: int) -> void:
	if Party.me(run).rest_used:
		return
	_set_desc(describe(i) if hovered else "")


func _set_desc(text: String) -> void:
	_desc.text = "[center]%s[/center]" % text


# —— 置き場所 ——

func _layout() -> void:
	if run == null:
		return
	var s := size
	_title.position = Vector2(0, s.y * TITLE_Y - 34)
	_title.size = Vector2(s.x, 70)
	for i in tiles.size():
		var t := tiles[i]
		var cx := s.x / 2.0 + (i - (tiles.size() - 1) / 2.0) * TILE_GAP
		var rise := _rise[i] if i < _rise.size() else 0.0
		t.position = Vector2(cx, s.y * TILES_Y + rise) - RestTile.TILE_SIZE / 2.0
	var desc_y := s.y * (DESC_Y if not Party.me(run).rest_used else TILES_Y)
	_desc.position = Vector2(s.x * 0.2, desc_y)
	_desc.size = Vector2(s.x * 0.6, 0)
	# 焚き火：背景と同じ「覆うように拡大」の写し方で絵の座標を画面へ
	var img := BACKDROP.get_size()
	var k := maxf(s.x / img.x, s.y / img.y)
	var off := (s - img * k) / 2.0
	for c: Control in _fire:
		var r: Rect2 = GLOW_RECT if c == _fire[0] else FLAME_RECT
		c.position = off + r.position * k
		c.size = r.size * k
	_embers.position = off + EMBER_AT * k
	_embers.scale = Vector2.ONE * k / 0.703   # 1080 の高さで合わせた粒の大きさ


func _shader_rect(shader: Shader) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	r.material = mat
	add_child(r)
	return r


## 火の粉：炎の先から上へふわふわ昇って消える小さな橙の粒（タイトル画面の焚き火も使う）。
static func make_embers() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = 22
	p.lifetime = 1.8
	p.preprocess = 2.0
	p.texture = EMBER_TEX
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(28, 6, 0)
	m.direction = Vector3(0, -1, 0)
	m.spread = 18.0
	m.initial_velocity_min = 30.0
	m.initial_velocity_max = 75.0
	m.gravity = Vector3(0, -12, 0)
	m.scale_min = 0.05
	m.scale_max = 0.11
	m.angular_velocity_min = 0.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.85, 0.4, 0), Color(1, 0.75, 0.3, 1), Color(1, 0.4, 0.12, 0.8), Color(0.8, 0.2, 0.05, 0)])
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m
	return p


## 上を暗くする縦のグラデーション（見出しと説明を読みやすく）。
static func _top_shade() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.75])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	return tex


# —— 演出 ——

## 見出しがフェードし、タイルが少し下から順に浮かび上がる。
func _play_enter() -> void:
	var t := create_tween().set_parallel(true)
	_enter_tween = t
	_title.modulate.a = 0.0
	t.tween_property(_title, "modulate:a", 1.0, 0.3)
	_rise.resize(tiles.size())
	for i in tiles.size():
		var tile := tiles[i]
		tile.modulate.a = 0.0
		_set_rise(RISE, i)
		var delay := 0.1 + i * 0.08
		t.tween_property(tile, "modulate:a", 1.0, 0.22).set_delay(delay)
		t.tween_method(_set_rise.bind(i), RISE, 0.0, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## タイル i を本来の位置から下へずらす量（入ってくる演出。置き場所は _layout が決める）。
func _set_rise(v: float, i: int) -> void:
	if i < _rise.size():
		_rise[i] = v
	_layout()

class_name MainMenuScreen extends Screen
## ⑤ Presentation：メインメニュー（GameDesign §15.2、U01）。
## - 「続きから」：セーブがあるときだけ表示。読めなければ「セーブを読み込めません」にして押せなくする。
## - 「新しいラン」「ランを放棄」：セーブがあるときは上書き / 削除の確認のため、もう 1 回押す。
## - シード：セーブのシードを表示する。デバッグビルドでは固定シードを入力できる。
## - 「図鑑」：全カード・レリック・ポーションを眺める画面（CompendiumScreen）へ。
## - デバッグビルドでは「全カードで開始」（初期デッキを全カードにする。カードの見た目の確認用）を選べる。
## 言語の切り替えは M7。
## 見た目は StS2 のタイトルに合わせた：全画面の背景の絵（焚き火を囲む 3 人と遠くの塔）＋ 金のロゴ ＋ 文字だけのメニュー。
## 背景は動かす：空の雲がうねる（title_sky.gdshader）・焚き火の炎と光の揺らぎと火の粉（休憩所と同じ部品）・塔の灯りの明滅・霧・漂う光。
## 炎・光の位置は背景の絵の px（1920×1072）で持ち、背景と同じ「覆うように拡大」の写し方で画面へ置く。絵を差し替えたら測り直す。

signal continue_requested(state: RunState)
signal new_run_requested(seed_value: int, debug_all_cards: bool)
signal compendium_requested
## 「協力プレイ」：LAN のロビーへ（GameDesign §21）。
signal coop_requested
signal quit_requested

const CONFIRM_NEW: StringName = &"new"
const CONFIRM_ABANDON: StringName = &"abandon"

const BACKDROP: Texture2D = preload("res://assets/textures/backgrounds/title_campfire.jpg")
const SKY_SHADER: Shader = preload("res://assets/shaders/title_sky.gdshader")
const FLAME_SHADER: Shader = preload("res://assets/shaders/campfire_flame.gdshader")
const GLOW_SHADER: Shader = preload("res://assets/shaders/campfire_glow.gdshader")
const MIST_SHADER: Shader = preload("res://assets/shaders/ground_mist.gdshader")
const FIREFLY_SHADER: Shader = preload("res://assets/shaders/fireflies.gdshader")
## 焚き火（炎 / 周りの光）と火の粉の出る所、塔の灯り（絵の px）。
const FLAME_RECT: Rect2 = Rect2(466, 826, 56, 82)
const GLOW_RECT: Rect2 = Rect2(300, 700, 384, 300)
const EMBER_AT: Vector2 = Vector2(492, 818)
const TOWER_RECT: Rect2 = Rect2(1340, 236, 80, 80)
## メニューのホバー：少し大きくする。
const HOVER_SCALE: float = 1.08
const HOVER_SECONDS: float = 0.12
## 開いたときのフェードイン（ロゴ → メニュー）。
const LOGO_FADE: float = 0.8
const MENU_FADE: float = 0.5

var _saved: RunState
var _has_save: bool = false
## 2 回押しの確認中のボタン（&"" = なし）。
var _confirming: StringName = &""
## 絵の座標で置く飾り：[Control, 絵の px の矩形]。
var _placed: Array[Array] = []
var _embers: GPUParticles2D

@onready var _logo: TextureRect = %Logo
@onready var _menu: VBoxContainer = %Menu
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _continue: Button = %ContinueButton
@onready var _save_info: Label = %SaveInfo
@onready var _new_run: Button = %NewRunButton
@onready var _seed_edit: LineEdit = %SeedEdit
@onready var _all_cards: CheckBox = %AllCardsCheck
@onready var _abandon: Button = %AbandonButton
@onready var _compendium: Button = %CompendiumButton
@onready var _quit: Button = %QuitButton
@onready var _hint: Label = $Hint
var _coop: Button


func _ready() -> void:
	_continue.pressed.connect(_on_continue_pressed)
	_new_run.pressed.connect(_on_new_run_pressed)
	_abandon.pressed.connect(_on_abandon_pressed)
	_compendium.pressed.connect(_on_compendium_pressed)
	_quit.pressed.connect(quit_requested.emit)
	# 「協力プレイ」は「新しいラン」の下に足す（シーンは変えず、同じ見た目のボタンを作る）。
	_coop = Button.new()
	_coop.text = "協力プレイ"
	_coop.name = "CoopButton"
	_coop.theme_type_variation = _new_run.theme_type_variation
	_coop.focus_mode = _new_run.focus_mode
	_coop.flat = _new_run.flat
	_coop.alignment = _new_run.alignment
	_coop.custom_minimum_size = _new_run.custom_minimum_size
	_coop.size_flags_horizontal = _new_run.size_flags_horizontal
	_menu.add_child(_coop)
	_menu.move_child(_coop, _new_run.get_index() + 1)
	_coop.pressed.connect(coop_requested.emit)
	_seed_edit.visible = OS.is_debug_build()
	_all_cards.visible = OS.is_debug_build()
	_debug_panel.visible = OS.is_debug_build()
	_hint.text = UiText.CONTROLS_HINT
	_build_backdrop()
	for b: Button in [_continue, _new_run, _coop, _abandon, _compendium, _quit]:
		b.mouse_entered.connect(_hover.bind(b, true))
		b.mouse_exited.connect(_hover.bind(b, false))
		b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	resized.connect(_layout_backdrop)
	_layout_backdrop()
	_fade_in()
	refresh_save()


# —— 背景 ——

## 背景の絵（空が動く）→ 霧 → 奥の漂う光 → 焚き火の光 → 炎 → 火の粉 → 塔の灯り。どれもメニューより後ろ。
func _build_backdrop() -> void:
	var bg := TextureRect.new()
	bg.texture = BACKDROP
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sky := ShaderMaterial.new()
	sky.shader = SKY_SHADER
	bg.material = sky
	var layers: Array[Control] = [bg]
	var mist := _full_rect(MIST_SHADER, {
		&"amount": 0.2, &"mist_color": Color(0.5, 0.56, 0.68), &"top": 0.5, &"bottom": 0.9, &"speed": 0.012})
	layers.append(mist)
	layers.append(_full_rect(FIREFLY_SHADER, {
		&"density": 0.22, &"color": Color(1.0, 0.72, 0.38), &"brightness": 0.8, &"y_top": 0.45, &"y_bottom": 0.95}))
	var glow := _shader_rect(GLOW_SHADER, {&"intensity": 0.42})
	var flame := _shader_rect(FLAME_SHADER, {&"intensity": 0.55})
	var tower := _shader_rect(GLOW_SHADER, {
		&"glow_color": Color(1.0, 0.62, 0.25), &"intensity": 0.9, &"flicker": 0.45, &"speed": 0.8})
	_placed = [[glow, GLOW_RECT], [flame, FLAME_RECT], [tower, TOWER_RECT]]
	layers.append_array([glow, flame, tower])
	_embers = RestScreen.make_embers()
	for i in layers.size():
		add_child(layers[i])
		move_child(layers[i], i)
	add_child(_embers)
	move_child(_embers, layers.size())


func _full_rect(shader: Shader, params: Dictionary) -> ColorRect:
	var r := _shader_rect(shader, params)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


func _shader_rect(shader: Shader, params: Dictionary) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key: StringName in params:
		mat.set_shader_parameter(key, params[key])
	r.material = mat
	return r


## 背景と同じ「覆うように拡大」の写し方で、絵の px の飾りを画面へ置く。
func _layout_backdrop() -> void:
	var s := size
	var img := BACKDROP.get_size()
	var k := maxf(s.x / img.x, s.y / img.y)
	var off := (s - img * k) / 2.0
	for pair: Array in _placed:
		var c: Control = pair[0]
		var r: Rect2 = pair[1]
		c.position = off + r.position * k
		c.size = r.size * k
	_embers.position = off + EMBER_AT * k
	_embers.scale = Vector2.ONE * k / 0.703 * 0.6   # 休憩所より焚き火が小さいので粒も小さく


func _hover(button: Button, on: bool) -> void:
	if button.disabled:
		on = false
	var t := button.create_tween()
	t.tween_property(button, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), HOVER_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fade_in() -> void:
	_logo.modulate.a = 0.0
	_menu.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_logo, "modulate:a", 1.0, LOGO_FADE)
	t.tween_property(_menu, "modulate:a", 1.0, MENU_FADE)


## セーブの有無を読み直して表示を更新する。
func refresh_save() -> void:
	_has_save = SaveManager.has_run()
	_saved = SaveManager.load_run(Content.library) if _has_save else null
	_continue.visible = _has_save
	_continue.disabled = _saved == null
	_continue.text = "続きから" if _saved != null or not _has_save else "セーブを読み込めません"
	_abandon.visible = _has_save
	_save_info.visible = _saved != null
	if _saved != null:
		_save_info.text = "第 %d アクト　HP %d/%d　%d G　シード %d" % [
			_saved.act_index + 1, _saved.hp, _saved.max_hp, _saved.gold, _saved.seed_value]
	_set_confirming(&"")


func _on_continue_pressed() -> void:
	_set_confirming(&"")
	if _saved != null:
		continue_requested.emit(_saved)


func _on_new_run_pressed() -> void:
	if _has_save and _confirming != CONFIRM_NEW:
		_set_confirming(CONFIRM_NEW)
		return
	_set_confirming(&"")
	new_run_requested.emit(_seed(), _all_cards.visible and _all_cards.button_pressed)


func _on_abandon_pressed() -> void:
	if _confirming != CONFIRM_ABANDON:
		_set_confirming(CONFIRM_ABANDON)
		return
	SaveManager.delete_run()
	Log.info(&"run", "run abandoned from the main menu")
	refresh_save()


func _on_compendium_pressed() -> void:
	_set_confirming(&"")
	compendium_requested.emit()


func _set_confirming(which: StringName) -> void:
	_confirming = which
	_new_run.text = "もう一度押すと上書きして開始" if which == CONFIRM_NEW else "新しいラン"
	_abandon.text = "もう一度押すと放棄（セーブを削除）" if which == CONFIRM_ABANDON else "ランを放棄"


func _seed() -> int:
	var text := _seed_edit.text.strip_edges()
	if _seed_edit.visible and text.is_valid_int():
		return text.to_int()
	return randi()

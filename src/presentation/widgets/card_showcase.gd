class_name CardShowcase extends Control
## ⑤ Presentation：数枚から 1 枚を選ぶときの見た目（StS2 の「Choose a Card」。CardListModal の showcase で使う）。
## パネルは無く、暗くした画面の上にリボン・横 1 列のカード・スキップのボタンを直接置く。左に「目」のボタン（強化後の表示）。
## 演出は StS2 の録画（30fps）を測って合わせた：
## - 出てくる：カードは中央に重なった暗い影から左右へ広がる（0.2 秒、最初の 1 フレームで 6 割進む ease-out）と同時に明るくなる。
##   リボンは 20px 下・半透明から上がって少し行き過ぎて戻る。スキップは少し上から下りる。
## - ホバー：0.8 → 1.0 倍へ素早く（0.07 秒）、離すとゆっくり（0.15 秒）戻る。隣のカードは外へ少しずれる。足元の青い光が強くなる。
## - レアのカードの後ろでは金色の放射光がずっと回っている（card_rays.gdshader）。
## - 選んだ：ほかのカードは消え、選んだカードは上部バーのデッキへ縮みながら飛ぶ（fly_to が無ければその場で消える）。

signal skip_pressed

const RIBBON: Texture2D = preload("res://assets/textures/ui/reward/ribbon.png")
const HEX: Texture2D = preload("res://assets/textures/ui/reward/hex.png")
const HEX_HOVER: Texture2D = preload("res://assets/textures/ui/reward/hex_hover.png")
const EYE: Texture2D = preload("res://assets/textures/ui/reward/eye.png")
const EYE_HOVER: Texture2D = preload("res://assets/textures/ui/reward/eye_hover.png")
const HALO: Texture2D = preload("res://assets/textures/ui/reward/halo.png")
const RAYS_SHADER: Shader = preload("res://assets/shaders/card_rays.gdshader")
const FONT: Font = preload("res://assets/fonts/banner_mincho.ttf")

## 並んでいるときの縮尺（ホバーで 1.0 = CardView の本来の大きさ。用語の説明はこの大きさの横に出る）。
const CARD_SCALE: float = 0.8
const HOVER_SCALE: float = 1.0
## カードの間隔（カードの幅に対する比。録画では 1.44）と、ホバー中に隣のカードが外へずれる量。
const SPACING: float = 1.44
const NUDGE: float = 14.0
## 高さの割合：リボン・カード・スキップ。目のボタンの横位置。
const RIBBON_Y: float = 0.245
const CARD_Y: float = 0.56
const SKIP_Y: float = 0.86
const EYE_X: float = 0.095
const RIBBON_SCALE: float = 0.72
const SPREAD_TIME: float = 0.2
const HOVER_IN: float = 0.07
const HOVER_OUT: float = 0.15
## 出てくるときのカードの色（暗い影）。
const SHADOW: Color = Color(0.16, 0.16, 0.2, 0.55)
## 足元の光：普段 / ホバー中。
const HALO_COLOR: Color = Color(0.45, 0.8, 1.0, 0.3)
const HALO_HOVER_ALPHA: float = 0.75
const FLY_TIME: float = 0.42
const FLY_SCALE: float = 0.12

var views: Array[CardView] = []
## 強化後を表示しているか（目のボタン）。
var upgraded_shown: bool = false
var skip_button: Button
var eye_button: Button

var _slots: Array[Control] = []
var _halos: Array[TextureRect] = []
var _entries: Array = []
var _hovered: int = -1
var _ribbon: TextureRect
var _ribbon_label: Label
var _info: Label
var _intro: float = 1.0
var _picking: bool = false


## entries は CardListModal と同じ形。views は呼び出し側（CardListModal）が作って渡す。
func setup(title: String, info: String, entries: Array, card_views: Array[CardView], cancellable: bool, cancel_text: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entries = entries
	_build_ribbon(title, info)
	for i in card_views.size():
		_add_slot(card_views[i], entries[i][&"data"])
	skip_button = _hex_button(HEX, HEX_HOVER, cancel_text)
	skip_button.visible = cancellable
	skip_button.pressed.connect(skip_pressed.emit)
	add_child(skip_button)
	eye_button = _hex_button(EYE, EYE_HOVER, "")
	eye_button.toggle_mode = true
	eye_button.tooltip_text = "強化後を表示\nカードを強化したときの効果を表示する"
	eye_button.toggled.connect(show_upgraded)
	eye_button.visible = _any_upgradable()
	add_child(eye_button)
	resized.connect(_layout)
	_layout()


## 入ってくる演出。
func play_enter() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_method(_set_intro, 0.0, 1.0, SPREAD_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	for slot in _slots:
		slot.modulate = SHADOW
		t.tween_property(slot, "modulate", Color.WHITE, SPREAD_TIME + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ribbon.modulate.a = 0.5
	t.tween_property(_ribbon, "modulate:a", 1.0, 0.15)
	for b: Control in [skip_button, eye_button]:
		b.modulate.a = 0.0
		t.tween_property(b, "modulate:a", 1.0, 0.2)


## 強化後の表示を切り替える（目のボタン。選ぶのは元のカードのまま）。
func show_upgraded(on: bool) -> void:
	upgraded_shown = on
	for i in views.size():
		var data: CardData = _entries[i][&"data"]
		if on and data.upgraded != null:
			views[i].show_card(data.upgraded, UiText.card_text(data.upgraded))
		else:
			views[i].show_card(data, _entries[i].get(&"text", ""), _entries[i].get(&"card"), _entries[i].get(&"cost", -1))
	if eye_button.button_pressed != on:
		eye_button.set_pressed_no_signal(on)


## 選んだ：ほかを消し、選んだカードを fly_to（画面座標。INF ならその場）へ飛ばす。done は ほかが消えた後（0.15 秒）に呼ぶ。
## 選んだカードは画面の外の CanvasLayer に移すので、パネルを閉じても飛び続ける。
func play_pick(index: int, fly_to: Vector2, done: Callable) -> void:
	if _picking:
		return
	_picking = true
	var t := create_tween().set_parallel(true)
	for i in _slots.size():
		if i != index:
			t.tween_property(_slots[i], "modulate:a", 0.0, 0.12)
	for c: Control in [_ribbon, skip_button, eye_button, _halos[index]]:
		t.tween_property(c, "modulate:a", 0.0, 0.12)
	t.chain().tween_callback(done)
	_fly(views[index], fly_to)


func is_picking() -> bool:
	return _picking


# —— 組み立て ——

func _build_ribbon(title: String, info: String) -> void:
	_ribbon = TextureRect.new()
	_ribbon.texture = RIBBON
	_ribbon.size = RIBBON.get_size()
	_ribbon.scale = Vector2.ONE * RIBBON_SCALE
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ribbon)
	_ribbon_label = Label.new()
	_ribbon_label.text = title
	_ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ribbon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ribbon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ribbon_label.offset_bottom = -RIBBON.get_size().y * 0.18
	_ribbon_label.add_theme_font_override(&"font", FONT)
	_ribbon_label.add_theme_font_size_override(&"font_size", 54)
	_ribbon_label.add_theme_color_override(&"font_color", Color(1.0, 0.97, 0.88))
	_ribbon_label.add_theme_constant_override(&"outline_size", 10)
	_ribbon_label.add_theme_color_override(&"font_outline_color", Color(0.22, 0.12, 0.06))
	_ribbon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.add_child(_ribbon_label)
	_info = Label.new()
	_info.text = info
	_info.visible = not info.is_empty()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.theme_type_variation = &"LabelSmall"
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)


## カード 1 枚の置き場：足元の光（・レアなら放射光）・カード。カードは中心を軸に縮める。
func _add_slot(view: CardView, data: CardData) -> void:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size = CardView.BASE_SIZE * CARD_SCALE
	add_child(slot)
	var center := slot.size / 2.0
	if UiText.frame_rarity(data) == CardData.Rarity.RARE:
		var rays := ColorRect.new()
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rays.size = Vector2.ONE * CardView.BASE_SIZE.y * 1.9
		rays.position = center - rays.size / 2.0
		var mat := ShaderMaterial.new()
		mat.shader = RAYS_SHADER
		mat.set_shader_parameter(&"seed", float(_slots.size()) * 1.7)
		rays.material = mat
		slot.add_child(rays)
	var halo := TextureRect.new()
	halo.texture = HALO
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.size = Vector2(slot.size.x * 1.9, slot.size.y * 1.5)
	halo.position = center - halo.size / 2.0 + Vector2(0, slot.size.y * 0.12)
	halo.modulate = HALO_COLOR
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = add
	slot.add_child(halo)
	slot.add_child(view)
	view.position = center - CardView.BASE_SIZE / 2.0
	view.pivot_offset = CardView.BASE_SIZE / 2.0
	view.scale = Vector2.ONE * CARD_SCALE
	view.hover_changed.connect(_on_hover_changed)
	views.append(view)
	_slots.append(slot)
	_halos.append(halo)


func _hex_button(normal: Texture2D, hover: Texture2D, label: String) -> Button:
	var b := TipButton.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = normal.get_size()
	b.size = normal.get_size()
	for state: StringName in [&"normal", &"disabled"]:
		b.add_theme_stylebox_override(state, _tex_style(normal))
	for state: StringName in [&"hover", &"pressed", &"hover_pressed"]:
		b.add_theme_stylebox_override(state, _tex_style(hover))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	b.add_theme_font_override(&"font", FONT)
	b.add_theme_font_size_override(&"font_size", 34)
	b.add_theme_constant_override(&"outline_size", 8)
	b.add_theme_color_override(&"font_outline_color", Color(0.05, 0.14, 0.2))
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color(1.0, 0.97, 0.9))
	return b


static func _tex_style(tex: Texture2D) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	return s


func _any_upgradable() -> bool:
	for e: Dictionary in _entries:
		if e.has(&"card"):
			return false   # 戦闘中のカード（動的な説明）は強化後を出さない
	for e: Dictionary in _entries:
		if (e[&"data"] as CardData).upgraded != null:
			return true
	return false


# —— 置き場所 ——

## 置き場所は画面の大きさから決める。_intro（0 = 中央に重なる、1 = 並んだ）と、ホバー中の隣のずれもここで足す。
func _layout() -> void:
	var s := size
	var rs := RIBBON.get_size() * RIBBON_SCALE
	_ribbon.position = Vector2(s.x / 2.0 - rs.x / 2.0, s.y * RIBBON_Y - rs.y / 2.0 + (1.0 - _intro) * 20.0)
	_info.position = Vector2(0, s.y * RIBBON_Y + rs.y * 0.42)
	_info.size = Vector2(s.x, 32)
	var n := _slots.size()
	var gap := CardView.BASE_SIZE.x * CARD_SCALE * SPACING
	for i in n:
		var slot := _slots[i]
		var x := s.x / 2.0 + (i - (n - 1) / 2.0) * gap * _intro
		if _hovered >= 0 and i != _hovered:
			x += NUDGE * signf(i - _hovered)
		slot.position = Vector2(x, s.y * CARD_Y) - slot.size / 2.0
	skip_button.position = Vector2(s.x / 2.0, s.y * SKIP_Y - (1.0 - _intro) * 25.0) - skip_button.size / 2.0
	eye_button.position = Vector2(s.x * EYE_X, s.y * CARD_Y) - eye_button.size / 2.0


func _set_intro(v: float) -> void:
	_intro = v
	_layout()


# —— ホバー ——

func _on_hover_changed(view: CardView, hovered: bool) -> void:
	if _picking:
		return
	var i := views.find(view)
	if i < 0:
		return
	if hovered:
		_hovered = i
	elif _hovered == i:
		_hovered = -1
	_slots[i].z_index = 1 if hovered else 0
	var t := create_tween().set_parallel(true)
	var time := HOVER_IN if hovered else HOVER_OUT
	t.tween_property(view, "scale", Vector2.ONE * (HOVER_SCALE if hovered else CARD_SCALE), time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_halos[i], "modulate:a", HALO_HOVER_ALPHA if hovered else HALO_COLOR.a, time)
	_layout()


# —— 選んだカードを飛ばす ——

func _fly(view: CardView, to: Vector2) -> void:
	view.tips_enabled = false
	view.hide_tips()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 6
	get_tree().root.add_child(layer)
	var xf := view.get_global_transform()   # モーダルの CanvasLayer も移す先も変換なしなので、そのまま使える
	view.get_parent().remove_child(view)
	layer.add_child(view)
	# 中心を軸に縮めているので、見た目の中心 = 移す前の変換で (大きさ / 2) を写した点
	view.pivot_offset = CardView.BASE_SIZE / 2.0
	view.scale = xf.get_scale()
	view.position = xf * (CardView.BASE_SIZE / 2.0) - CardView.BASE_SIZE / 2.0
	var t := view.create_tween()
	t.tween_property(view, "scale", view.scale * 1.08, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if to == Vector2.INF:
		t.tween_property(view, "modulate:a", 0.0, 0.2)
	else:
		t.tween_property(view, "position", to - CardView.BASE_SIZE / 2.0, FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(view, "scale", Vector2.ONE * FLY_SCALE, FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(view, "rotation", deg_to_rad(-12.0), FLY_TIME)
		t.parallel().tween_property(view, "modulate:a", 0.0, 0.1).set_delay(FLY_TIME - 0.1)
	t.tween_callback(layer.queue_free)

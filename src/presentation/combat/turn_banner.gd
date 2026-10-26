class_name TurnBanner extends Control
## ⑤ Presentation：ターンの切り替わりを知らせる大きな文字（Slay the Spire 2 の録画を 30fps で測って合わせた。2026-10-20）。
## - あなたのターン：フェードインしながら浮き上がり、サブタイトル「ターン N」がタイトルの裏から下へ滑り出る。
## - 敵のターン：大きく出て縮みながら現れ（叩きつけ）、金から赤へ変わってから消える。赤くなる頃に敵が動き出す。
## 進行は止めない（入力も塞がない）。再生の倍率は set_speed で受ける（早送りで一緒に速くなる）。

const FONT: Font = preload("res://assets/fonts/banner_mincho.ttf")
const TITLE_SIZE: int = 92
const SUB_SIZE: int = 36
const GOLD: Color = Color("#E4CA78")
const SUB_COLOR: Color = Color("#A2C5D3")
const ENEMY_RED: Color = Color("#C4512B")
## タイトルの中心の高さ（画面の高さに対する割合）。StS2 は 0.43 だが、TryCard はキャラの頭が高いので重ならない所へ上げた。
const CENTER_Y: float = 0.35
## あなたのターン：浮き上がる量（px）と、サブタイトルが下へ滑る量。
const RISE: float = 55.0
const SUB_GAP: float = 64.0
## 敵のターン：出始めの拡大率。
const SLAM_SCALE: float = 1.85

var _title: Label
var _sub: Label
var _tween: Tween
var _speed: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _make_label(TITLE_SIZE, 14)
	_sub = _make_label(SUB_SIZE, 8)
	clear()


func show_player(turn_no: int) -> void:
	_title.text = "あなたのターン"
	_sub.text = "ターン %d" % turn_no
	var c := _start()
	_title.self_modulate = GOLD
	_sub.self_modulate = SUB_COLOR
	_title.position = _title_pos(c) + Vector2(0, RISE)
	_sub.position = _sub_pos(c) - Vector2(0, SUB_GAP)
	_sub.visible = true
	var t := _tween
	t.set_parallel(true)
	t.tween_property(_title, "position", _title_pos(c), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_title, "modulate:a", 1.0, 0.4)
	t.tween_property(_sub, "position", _sub_pos(c), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.05)
	t.tween_property(_sub, "modulate:a", 1.0, 0.4).set_delay(0.05)
	t.tween_property(_title, "modulate:a", 0.0, 0.25).set_delay(1.9)
	t.tween_property(_sub, "modulate:a", 0.0, 0.25).set_delay(1.9)
	t.chain().tween_callback(clear)


func show_enemy() -> void:
	_title.text = "敵のターン"
	var c := _start()
	_sub.visible = false
	_title.self_modulate = GOLD
	_title.position = _title_pos(c)
	_title.scale = Vector2.ONE * SLAM_SCALE
	var t := _tween
	t.set_parallel(true)
	t.tween_property(_title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_title, "modulate:a", 1.0, 0.35)
	t.tween_property(_title, "self_modulate", ENEMY_RED, 0.25).set_delay(1.4)
	t.tween_property(_title, "modulate:a", 0.0, 0.4).set_delay(1.55)
	t.chain().tween_callback(clear)


## すぐ消す（戦闘終了など）。
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_title.modulate.a = 0.0
	_sub.modulate.a = 0.0
	_title.scale = Vector2.ONE


func is_showing() -> bool:
	return _tween != null and _tween.is_valid()


## 再生の倍率（CombatPresenter.current_speed）。
func set_speed(speed: float) -> void:
	_speed = speed
	if _tween != null and _tween.is_valid():
		_tween.set_speed_scale(speed)


## 前の演出を止めて新しい Tween を用意し、タイトルの中心を返す。
func _start() -> Vector2:
	clear()
	for l: Label in [_title, _sub]:
		l.reset_size()
		l.pivot_offset = l.size / 2.0
	_tween = create_tween()
	_tween.set_speed_scale(_speed)
	return Vector2(size.x / 2.0, size.y * CENTER_Y)


func _title_pos(center: Vector2) -> Vector2:
	return center - _title.size / 2.0


func _sub_pos(center: Vector2) -> Vector2:
	return center + Vector2(-_sub.size.x / 2.0, _title.size.y / 2.0 - _sub.size.y / 2.0 + SUB_GAP * 0.35)


## 白い字に柔らかい影。色は self_modulate、出入りは modulate:a で付ける（影は黒のまま一緒に消える）。
func _make_label(font_size: int, shadow: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", Color.WHITE)
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 4)
	l.add_theme_constant_override(&"shadow_outline_size", shadow)
	add_child(l)
	return l

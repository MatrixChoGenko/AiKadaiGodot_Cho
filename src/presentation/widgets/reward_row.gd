class_name RewardRow extends TipButton
## ⑤ Presentation：戦利品のパネルの 1 行（StS2 の「Loot!」の青い帯）。左にアイコン、ホバーで四隅に金のカギが出る。
## 受け取ったら play_remove() で縮んで消え、下の行が詰まる（VBoxContainer の中に置く）。

const ROW: Texture2D = preload("res://assets/textures/ui/reward/row.png")
const ROW_HOVER: Texture2D = preload("res://assets/textures/ui/reward/row_hover.png")
const CORNER: Texture2D = preload("res://assets/textures/ui/reward/corner.png")
const SIZE: Vector2 = Vector2(440, 84)
const ICON_WIDTH: int = 52
## 四隅のカギが行の外へ出る量（px）と、ホバー中に脈打つ幅。
const CORNER_OUT: float = 8.0
const CORNER_PULSE: float = 4.0
const REMOVE_TIME: float = 0.18

var _corners: Array[TextureRect] = []
var _pulse: Tween
var removing: bool = false


func _init(text_value: String, icon_texture: Texture2D) -> void:
	text = text_value
	icon = icon_texture
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_contents = true
	add_theme_constant_override(&"icon_max_width", ICON_WIDTH)
	add_theme_constant_override(&"h_separation", 16)
	add_theme_font_size_override(&"font_size", 26)
	add_theme_constant_override(&"outline_size", 6)
	add_theme_color_override(&"font_outline_color", Color(0.05, 0.12, 0.18))
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		add_theme_color_override(c, Color(1.0, 0.97, 0.9))
	var normal := _style(ROW)
	var hover := _style(ROW_HOVER)
	add_theme_stylebox_override(&"normal", normal)
	add_theme_stylebox_override(&"hover", hover)
	add_theme_stylebox_override(&"pressed", hover)
	add_theme_stylebox_override(&"disabled", normal)
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	for i in 4:
		var c := TextureRect.new()
		c.texture = CORNER
		c.flip_h = i % 2 == 1
		c.flip_v = i >= 2
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.visible = false
		_corners.append(c)


func _ready() -> void:
	# カギは行の外へはみ出すので top_level にして clip_contents の切り抜きを受けないようにする（位置は _process で合わせる）
	for c in _corners:
		c.top_level = true
		add_child(c)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _process(_delta: float) -> void:
	if not _corners[0].visible:
		return
	var rect := get_global_rect()
	var out := CORNER_OUT + (sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.6) * 0.5 + 0.5) * CORNER_PULSE
	var cs := CORNER.get_size()
	_corners[0].global_position = rect.position - Vector2(out, out)
	_corners[1].global_position = Vector2(rect.end.x + out - cs.x, rect.position.y - out)
	_corners[2].global_position = Vector2(rect.position.x - out, rect.end.y + out - cs.y)
	_corners[3].global_position = rect.end + Vector2(out, out) - cs


## 受け取った：縮んで消える（下の行は VBoxContainer が詰める）。
func play_remove() -> void:
	if removing:
		return
	removing = true
	disabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_hover(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, REMOVE_TIME * 0.7)
	t.tween_property(self, "custom_minimum_size:y", 0.0, REMOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_callback(queue_free)


## 出てくる：delay 秒後にフェードで現れる。
func play_enter(delay: float) -> void:
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", 1.0, 0.18)


func _set_hover(on: bool) -> void:
	for c in _corners:
		c.visible = on and not removing


static func _style(tex: Texture2D) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = 24
	s.texture_margin_right = 24
	s.texture_margin_top = 16
	s.texture_margin_bottom = 20
	s.content_margin_left = 22
	s.content_margin_right = 18
	return s

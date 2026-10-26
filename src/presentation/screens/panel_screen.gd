class_name PanelScreen extends Screen
## ⑤ Presentation：中央のパネルにタイトル・本文・下部ボタンを並べるだけの簡素な画面の基底クラス。
## M4 の最小限の画面（報酬 / 宝箱 / ショップ / イベント / 休憩 / アクト移行 / 勝利・敗北）が使う（DevelopmentPlan M4）。
## 骨組みはここでコードで組む。M5 で各画面を作り込むときに、必要ならシーンでのレイアウトに置き換える。

## パネルの幅（広い画面は _init で変える）。
var panel_width: float = 1000.0
## 全画面の背景画像（null なら Main の暗い背景のまま。使う画面は _init で入れる）。
var backdrop_image: Texture2D = null

var title_label: Label
var body: VBoxContainer
var footer: HBoxContainer


func _ready() -> void:
	if backdrop_image != null:
		var bg := TextureRect.new()
		bg.texture = backdrop_image
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 64.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	panel.custom_minimum_size = Vector2(panel_width, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 22)
	panel.add_child(column)
	title_label = Label.new()
	title_label.theme_type_variation = &"LabelLarge"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)
	body = VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 14)
	column.add_child(body)
	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override(&"separation", 24)
	column.add_child(footer)


## 本文に 1 行のテキストを足す。
func add_text(text: String, small: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if small:
		label.theme_type_variation = &"LabelSmall"
	body.add_child(label)
	return label


## ボタンを足す（parent 省略時は本文）。
func add_button(text: String, on_pressed: Callable, parent: Container = null, variation: StringName = &"") -> Button:
	var b := TipButton.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = variation
	b.pressed.connect(on_pressed)
	(parent if parent != null else body).add_child(b)
	return b


func clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func clear_footer() -> void:
	for child in footer.get_children():
		footer.remove_child(child)
		child.queue_free()


## 画面内の案内（ゴールド不足、枠がいっぱい…）。
func notice(text: String) -> void:
	var label := add_text(text, true)
	label.modulate = Color(1.0, 0.7, 0.55)
	var t := label.create_tween()
	t.tween_interval(2.0)
	t.tween_callback(label.queue_free)

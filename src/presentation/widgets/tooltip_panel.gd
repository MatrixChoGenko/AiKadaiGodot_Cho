class_name TooltipPanel extends PanelContainer
## ⑤ Presentation：ツールチップ 1 枚（GameDesign §15.1 / Architecture §13.4、U11）。見出し ＋ 本文（BBCode）。表示だけで、クリックを妨げない。
## 使い方は 2 つ：
##   - Control の _make_custom_tooltip から for_tooltip() を返す（遅延と位置は Godot 任せ）。Godot は返した Control を
##     自前の PopupPanel（テーマの TooltipPanel の枠）に入れるので、こちらは枠を描かない。
##   - CardTips がカードの横に make() を何枚も並べる（こちらは自分で枠を描く）。
## 本文の高さは文字の大きさから先に計算して最小サイズに入れる（ポップアップは中身の最小サイズで大きさを決めるので、
## fit_content / 自動折り返しの高さが後から決まると、文字が切れた小さな枠になる）。
## 文字列で受け取るときは tooltip_text と同じ「1 行目 = 見出し、2 行目以降 = 本文」の書式。

const BODY_WIDTH: float = 340.0
const BODY_FONT_SIZE: int = 19
const LINE_SLACK: float = 6.0

static var _tag_regex: RegEx


static func make(title: String, body: String = "", framed: bool = true) -> TooltipPanel:
	var panel := TooltipPanel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if framed:
		panel.theme_type_variation = &"PanelTooltip"
	else:
		panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	panel.add_child(column)
	if not title.is_empty():
		var t := Label.new()
		t.theme_type_variation = &"TooltipTitle"
		t.text = title
		column.add_child(t)
	if not body.is_empty():
		var b := RichTextLabel.new()
		b.theme_type_variation = &"TooltipBody"
		b.bbcode_enabled = true
		b.scroll_active = false
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = body_size(body)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.text = body
		column.add_child(b)
	return panel


## 「見出し\n本文」の文字列から作る。
static func from_text(text: String, framed: bool = true) -> TooltipPanel:
	var lines := text.split("\n", true, 1)
	return make(lines[0], lines[1] if lines.size() > 1 else "", framed)


## _make_custom_tooltip 用（枠は Godot のポップアップが描く）。
static func for_tooltip(text: String) -> TooltipPanel:
	return from_text(text, false)


## 本文の表示サイズ（BBCode のタグを除いて、折り返し幅 BODY_WIDTH で測る。短い文は 1 行の幅に縮める）。
static func body_size(body: String) -> Vector2:
	if _tag_regex == null:
		_tag_regex = RegEx.create_from_string("\\[[^\\]]*\\]")
	var plain := _tag_regex.sub(body, "", true)
	var font := ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else ThemeDB.fallback_font
	var one_line := 0.0
	for line in plain.split("\n"):
		one_line = maxf(one_line, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_FONT_SIZE).x)
	var width := minf(BODY_WIDTH, ceilf(one_line) + LINE_SLACK)
	var h := font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, width - LINE_SLACK, BODY_FONT_SIZE).y
	return Vector2(width, ceilf(h) + LINE_SLACK)


func title() -> String:
	var t := get_child(0).get_child(0) as Label
	return t.text if t != null else ""

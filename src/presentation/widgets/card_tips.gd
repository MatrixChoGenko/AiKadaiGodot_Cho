class_name CardTips extends CanvasLayer
## ⑤ Presentation：カードのホバー中に、カードの横へ用語の説明（キーワード / ステータス）を縦に並べる（GameDesign §15.1 / Architecture §13.4、U11）。
## 中身は UiText.card_terms（KeywordScan で効果ツリーを走査した結果）から作り、説明文の文字列マッチはしない。
## CardView の子に置くが CanvasLayer なので、カードの modulate（暗転・半透明）や拡大・回転を受けず、すべての画面の上に出る。

const LAYER: int = 100
const GAP: float = 10.0
const MARGIN: float = 8.0

var _card: Control
var _column: VBoxContainer


func _init(card: Control, terms: Array) -> void:
	_card = card
	layer = LAYER
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	add_child(_column)
	for term: Array in terms:
		_column.add_child(TooltipPanel.make(term[0], term[1]))


func _ready() -> void:
	_place.call_deferred()


func _process(_delta: float) -> void:
	_place()


func count() -> int:
	return _column.get_child_count()


## カードの右に置く。画面の右端を越えるなら左に置く。下にはみ出すなら上へずらす。
func _place() -> void:
	if not is_instance_valid(_card) or not _card.is_inside_tree():
		return
	var rect := _card.get_global_rect()
	var view := _card.get_viewport_rect().size
	_column.reset_size()
	var s := _column.size
	var x := rect.end.x + GAP
	if x + s.x > view.x - MARGIN:
		x = rect.position.x - GAP - s.x
	var y := clampf(rect.position.y, MARGIN, maxf(MARGIN, view.y - s.y - MARGIN))
	_column.position = Vector2(x, y)

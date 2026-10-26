class_name TipButton extends Button
## ⑤ Presentation：tooltip_text（「見出し\n本文」、本文は BBCode 可）を共通のツールチップの見た目で出すボタン（U11）。


func _make_custom_tooltip(for_text: String) -> Object:
	return TooltipPanel.for_tooltip(for_text)

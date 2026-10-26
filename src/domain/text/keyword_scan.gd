class_name KeywordScan extends RefCounted
## ③ Domain：カード / ポーションの効果ツリーを走査し、使われているステータスとキーワードを集める（Architecture §13.4）。
## ツールチップはこれから作り、説明文の文字列マッチはしない。効果は children() で、値・条件はプロパティで辿る。

var statuses: Array[StatusData] = []
## KeywordData.Kind のビット和。
var keywords: int = 0


static func of_card(data: CardData) -> KeywordScan:
	var scan := KeywordScan.new()
	scan.keywords = data.keywords
	if data.cost_mode == CardData.CostMode.UNPLAYABLE:
		scan.keywords |= KeywordData.Kind.UNPLAYABLE
	for list: Array[CardEffect] in [data.on_play, data.on_draw, data.on_discard, data.on_exhaust, data.end_of_turn_in_hand]:
		for e in list:
			scan._visit_effect(e)
	return scan


static func of_effects(effects: Array[CardEffect]) -> KeywordScan:
	var scan := KeywordScan.new()
	for e in effects:
		scan._visit_effect(e)
	return scan


func _visit_effect(effect: CardEffect) -> void:
	if effect == null:
		return
	_visit_props(effect)
	for child in effect.children():
		_visit_effect(child)


## 効果・値・条件のプロパティから StatusData を拾う（別のカードなど単独のコンテンツの中には入らない）。
func _visit_props(res: Resource) -> void:
	for prop in res.get_property_list():
		var usage: int = prop["usage"]
		if not (usage & PROPERTY_USAGE_STORAGE and usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = res.get(prop["name"])
		if value is StatusData:
			if not statuses.has(value):
				statuses.append(value)
		elif value is ValueSource or value is Condition or value is TargetRule:
			_visit_props(value)
		elif value is Array:
			for item: Variant in value:
				if item is ValueSource or item is Condition:
					_visit_props(item)

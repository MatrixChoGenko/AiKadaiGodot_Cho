class_name CardText extends RefCounted
## ③ Domain：カードの動的テキスト（Architecture §6.6）。カードテキストを表示するすべての場所でこの関数を使う。
## テンプレートの {label} を効果のリアルタイムの数値に置き換え、基本値より高ければ緑、低ければ赤にする（BBCode）。
## キーワード（天賦 / 保留 / エセリアル / プレイ不可 / 廃棄）は自動で付け足す（GameDesign 付録 C の C14）。

const COLOR_UP: String = "#7ee787"
const COLOR_DOWN: String = "#ff7b72"

static var _placeholder: RegEx = RegEx.create_from_string("\\{([A-Za-z0-9_]+)\\}")


## combat が null なら戦闘外（報酬・ショップ・デッキ）で、基本値で表示する。
## keyword_names：KeywordData.Kind → 表示名（ContentLibrary.keywords から作る）。空ならキーワードを付けない。
static func render(data: CardData, card: Card = null, combat: Combat = null, target: Combatant = null,
		keyword_names: Dictionary = {}) -> String:
	var p: Preview
	if combat != null and card != null:
		p = combat.preview_card(card, target)
	else:
		p = Preview.new()
		var ctx := EffectContext.new()
		ctx.preview = true
		ctx.card = card
		for list: Array[CardEffect] in [data.on_play, data.on_draw, data.on_discard, data.on_exhaust, data.end_of_turn_in_hand]:
			for e in list:
				e.preview(ctx, p)
	var body := fill(data.text, p)
	var head := PackedStringArray()
	var tail := PackedStringArray()
	for kind: KeywordData.Kind in [KeywordData.Kind.UNPLAYABLE, KeywordData.Kind.INNATE, KeywordData.Kind.RETAIN, KeywordData.Kind.ETHEREAL]:
		if _has(data, kind) and keyword_names.has(kind):
			head.append("%s。" % keyword_names[kind])
	if _has(data, KeywordData.Kind.EXHAUST) and keyword_names.has(KeywordData.Kind.EXHAUST):
		tail.append("%s。" % keyword_names[KeywordData.Kind.EXHAUST])
	var lines := PackedStringArray()
	if not head.is_empty():
		lines.append("".join(head))
	if not body.is_empty():
		lines.append(body)
	if not tail.is_empty():
		lines.append("".join(tail))
	return "\n".join(lines)


## テンプレートの {label} をプレビューの値で置き換える。値が無い label はそのまま残す。
static func fill(template: String, p: Preview) -> String:
	var out := template
	for m in _placeholder.search_all(template):
		var key := StringName(m.get_string(1))
		if not p.values.has(key):
			continue
		var value: int = p.values[key]
		var base: int = p.base_values.get(key, value)
		var shown := str(value)
		if value > base:
			shown = "[color=%s]%d[/color]" % [COLOR_UP, value]
		elif value < base:
			shown = "[color=%s]%d[/color]" % [COLOR_DOWN, value]
		out = out.replace(m.get_string(0), shown)
	return out


## ContentLibrary.keywords から keyword_names を作る。
static func keyword_names_of(keywords: Array[KeywordData]) -> Dictionary:
	var names: Dictionary = {}
	for k in keywords:
		names[k.kind] = k.name
	return names


static func _has(data: CardData, kind: KeywordData.Kind) -> bool:
	if kind == KeywordData.Kind.UNPLAYABLE:
		return data.cost_mode == CardData.CostMode.UNPLAYABLE
	return data.keywords & kind != 0

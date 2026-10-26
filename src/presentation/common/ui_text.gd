class_name UiText extends RefCounted
## ⑤ Presentation：画面に出す固定の文言（日本語のみ。GameDesign §19 の 2026-10-19 決定）。
## 翻訳キーの仕組み（Architecture §16）は M7 で入れる。それまで UI の文言はここに集め、各画面に直書きしない。

const CARD_TYPES: Dictionary[CardData.Type, String] = {
	CardData.Type.ATTACK: "アタック", CardData.Type.SKILL: "スキル", CardData.Type.POWER: "パワー",
	CardData.Type.STATUS: "ステータス", CardData.Type.CURSE: "呪い",
}

const RARITIES: Dictionary[CardData.Rarity, String] = {
	CardData.Rarity.STARTER: "基本", CardData.Rarity.COMMON: "コモン", CardData.Rarity.UNCOMMON: "アンコモン",
	CardData.Rarity.RARE: "レア", CardData.Rarity.SPECIAL: "特殊",
}

const RELIC_RARITIES: Dictionary[RelicData.Rarity, String] = {
	RelicData.Rarity.STARTER: "初期", RelicData.Rarity.COMMON: "コモン", RelicData.Rarity.UNCOMMON: "アンコモン",
	RelicData.Rarity.RARE: "レア", RelicData.Rarity.BOSS: "ボス", RelicData.Rarity.SHOP: "ショップ",
}

const POTION_RARITIES: Dictionary[PotionData.Rarity, String] = {
	PotionData.Rarity.COMMON: "コモン", PotionData.Rarity.UNCOMMON: "アンコモン", PotionData.Rarity.RARE: "レア",
}

const NODE_TYPES: Dictionary[MapNode.Type, String] = {
	MapNode.Type.BATTLE: "戦闘", MapNode.Type.ELITE: "エリート", MapNode.Type.BOSS: "ボス",
	MapNode.Type.EVENT: "イベント", MapNode.Type.SHOP: "ショップ", MapNode.Type.REST: "休憩",
	MapNode.Type.TREASURE: "宝箱",
}

## プレイできない理由（GameDesign §5.3）。
const PLAY_REASONS: Dictionary[StringName, String] = {
	PlayResult.NOT_YOUR_TURN: "あなたのターンではない",
	PlayResult.NOT_IN_HAND: "手札にない",
	PlayResult.NOT_ENOUGH_ENERGY: "エネルギー不足",
	PlayResult.UNPLAYABLE: "プレイ不可",
	PlayResult.NEED_TARGET: "対象が必要",
	PlayResult.INVALID_TARGET: "対象が無効",
	PlayResult.BLOCKED_BY_EFFECT: "効果を実行できない",
	PlayResult.WAITING_FOR_CHOICE: "カード選択待ち",
	PlayResult.COMBAT_OVER: "戦闘終了",
	PlayResult.NO_POTION: "ポーションがない",
}

## 戦闘中のカード選択の既定の案内（効果に prompt が無いとき）。
const CHOICE_PROMPTS: Dictionary[ChooseCardsEffect.Action, String] = {
	ChooseCardsEffect.Action.DISCARD: "捨てるカードを選ぶ",
	ChooseCardsEffect.Action.EXHAUST: "廃棄するカードを選ぶ",
	ChooseCardsEffect.Action.RETAIN: "保留するカードを選ぶ",
	ChooseCardsEffect.Action.DUPLICATE: "複製するカードを選ぶ",
	ChooseCardsEffect.Action.TO_DRAW_TOP: "山札の一番上に戻すカードを選ぶ",
	ChooseCardsEffect.Action.TO_DRAW_BOTTOM: "山札の一番下に戻すカードを選ぶ",
	ChooseCardsEffect.Action.TO_HAND: "手札に加えるカードを選ぶ",
	ChooseCardsEffect.Action.TO_DISCARD: "捨て札に入れるカードを選ぶ",
}

const REQUEST_PROMPTS: Dictionary[RunChoiceRequest.Kind, String] = {
	RunChoiceRequest.Kind.REMOVE: "削除するカードを選ぶ",
	RunChoiceRequest.Kind.UPGRADE: "アップグレードするカードを選ぶ",
	RunChoiceRequest.Kind.PICK: "デッキに加えるカードを選ぶ",
}

const INTENT_NAMES: Dictionary[Intent.Kind, String] = {
	Intent.Kind.ATTACK: "攻撃", Intent.Kind.ATTACK_DEFEND: "攻撃と防御", Intent.Kind.ATTACK_DEBUFF: "攻撃と弱体化",
	Intent.Kind.DEFEND: "防御", Intent.Kind.BUFF: "強化", Intent.Kind.DEBUFF: "弱体化",
	Intent.Kind.SPECIAL: "特殊", Intent.Kind.SLEEP: "睡眠", Intent.Kind.UNKNOWN: "不明",
}

## 協力プレイ：自分は「進む」を押して、ほかの人を待っている（矢印のボタンの文言。バナーのフォント）。
const WAITING_FOR_PARTY: String = "待機中"

## ツールチップの本文の中の用語の色（TooltipTitle と同じ）。
const TERM_COLOR: Color = Color(1, 0.85, 0.45)
## イベントの選択肢の効果の色付け：[正規表現, 色]。上から順に当てる（「最大 HP +5」を「HP +5」より先に）。
const EVENT_DETAIL_COLORS: Array = [
	["[+-]?\\d+ ゴールド", "#f0c75e"],
	["呪い「[^」]+」(を \\d+ 枚)?", "#ff7a6a"],
	["HP -\\d+", "#ff7a6a"],
	["最大 HP \\+\\d+", "#8ee07a"],
	["HP \\+\\d+", "#8ee07a"],
	["\\d+% を回復", "#8ee07a"],
]

const CONTROLS_HINT: String = "カードをドラッグ / クリックでプレイ　右クリック / Esc：取り消し　Space / E：ターン終了　演出中にクリック：早送り"


static var _keyword_names: Dictionary = {}
static var _base_of: Dictionary = {}
static var _base_of_lib: ContentLibrary


static func card_type(t: CardData.Type) -> String:
	return CARD_TYPES.get(t, "?")


static func rarity(r: CardData.Rarity) -> String:
	return RARITIES.get(r, "?")


static func node_type(t: MapNode.Type) -> String:
	return NODE_TYPES.get(t, "?")


static func play_reason(reason: StringName) -> String:
	return PLAY_REASONS.get(reason, String(reason))


## 戦闘外（報酬・ショップ・デッキ）のカードテキスト。戦闘中は CombatController.card_text を使う。
static func card_text(data: CardData, card: Card = null) -> String:
	return CardText.render(data, card, null, null, keyword_names())


## カード面のフレームに使うレアリティ。アップグレード版は SPECIAL なので、基本版のレアリティを使う。
static func frame_rarity(data: CardData) -> CardData.Rarity:
	if _base_of_lib != Content.library:
		_base_of_lib = Content.library
		_base_of.clear()
		if Content.library != null:
			for c in Content.library.cards:
				if c.upgraded != null:
					_base_of[c.upgraded] = c
	var base: CardData = _base_of.get(data, data)
	return base.rarity


static func keyword_names() -> Dictionary:
	if _keyword_names.is_empty() and Content.library != null:
		_keyword_names = CardText.keyword_names_of(Content.library.keywords)
	return _keyword_names


## カードのコストの表示（X / プレイ不可は空）。
static func cost_label(data: CardData, cost: int = -1) -> String:
	match data.cost_mode:
		CardData.CostMode.X:
			return "X"
		CardData.CostMode.UNPLAYABLE:
			return ""
	return str(data.cost if cost < 0 else cost)


## ステータスの説明（{stacks} を置き換え）。
static func status_text(data: StatusData, stacks: int) -> String:
	return "%s %d\n%s" % [data.name, stacks, data.text.replace("{stacks}", str(stacks))]


static func block_text(block: int) -> String:
	return "ブロック %d\n受ける攻撃ダメージを先に吸収する。次の自分のターンの開始時に消える。" % block


## イベントの選択肢の効果（EventOption.detail）に色を付けた BBCode。ゴールド = 金、HP の減少・呪い = 赤、回復・最大 HP = 緑。
## 規則は EVENT_DETAIL_COLORS の正規表現（先に書いたものから順に、重ならない所だけ）。
static func event_detail_markup(detail: String) -> String:
	var spans: Array = []   # [start, end, color]
	for rule: Array in EVENT_DETAIL_COLORS:
		var re := RegEx.create_from_string(rule[0])
		for m in re.search_all(detail):
			var overlaps := false
			for s: Array in spans:
				if m.get_start() < s[1] and s[0] < m.get_end():
					overlaps = true
					break
			if not overlaps:
				spans.append([m.get_start(), m.get_end(), rule[1]])
	spans.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := ""
	var at := 0
	for s: Array in spans:
		out += detail.substr(at, s[0] - at) + "[color=%s]%s[/color]" % [s[2], detail.substr(s[0], s[1] - s[0])]
		at = s[1]
	return out + detail.substr(at)


static func relic_text(data: RelicData, counter: int = 0) -> String:
	return "%s\n%s" % [data.name, data.text] + ("\n（カウンタ %d）" % counter if counter > 0 else "")


## ポーションの説明。効果の数値はカードと同じく {label} を基本値で埋める。関わるステータスの説明を後ろに付ける。
static func potion_text(data: PotionData) -> String:
	var p := Preview.new()
	var ctx := EffectContext.new()
	ctx.preview = true
	for e in data.effects:
		e.preview(ctx, p)
	var text := "%s\n%s" % [data.name, CardText.fill(data.text, p)]
	for term in terms_of(KeywordScan.of_effects(data.effects)):
		text += "\n[color=#%s]%s[/color]：%s" % [TERM_COLOR.to_html(false), term[0], term[1]]
	return text


## カードのホバーで横に並べる用語（キーワード → ステータスの順）：[[見出し, 本文], ...]（U11）。
static func card_terms(data: CardData) -> Array:
	return terms_of(KeywordScan.of_card(data))


## 効果ツリーの走査結果から用語の一覧を作る（文字列マッチはしない。Architecture §13.4）。
## ステータスの説明の {stacks} は、数の決まっていない一般の説明なので「X」にする。
static func terms_of(scan: KeywordScan) -> Array:
	var terms: Array = []
	if Content.library != null:
		for k in Content.library.keywords:
			if scan.keywords & k.kind != 0:
				terms.append([k.name, k.text])
	for s in scan.statuses:
		terms.append([s.name, s.text.replace("{stacks}", "X")])
	return terms


## インテントの説明（見出し = 行動名）。
static func intent_text(intent: Intent, move_name: String) -> String:
	var title: String = move_name if not move_name.is_empty() else INTENT_NAMES.get(intent.kind, "")
	var lines: Array[String] = []
	if intent.is_attack():
		if intent.uncertain:
			lines.append("攻撃しようとしている。")
		elif intent.hits > 1:
			lines.append("%d ダメージ × %d 回（合計 %d）の攻撃をしようとしている。" % [intent.damage, intent.hits, intent.total_damage()])
		else:
			lines.append("%d ダメージの攻撃をしようとしている。" % intent.damage)
	if intent.block > 0:
		lines.append("ブロックを %d 得ようとしている。" % intent.block)
	match intent.kind:
		Intent.Kind.ATTACK_DEBUFF, Intent.Kind.DEBUFF:
			lines.append("デバフを付けようとしている。")
		Intent.Kind.BUFF:
			lines.append("自分を強化しようとしている。")
		Intent.Kind.DEFEND:
			if intent.block <= 0:
				lines.append("守りを固めようとしている。")
		Intent.Kind.SPECIAL:
			lines.append("何かを企んでいる。")
		Intent.Kind.SLEEP:
			lines.append("眠っている。")
		Intent.Kind.UNKNOWN:
			lines.append("意図がわからない。")
	return "%s\n%s" % [title, "\n".join(lines)]


static func floor_text(run: RunController) -> String:
	var node := run.state.current_node()
	var floor_no := node.row + 1 if node != null else 0
	return "第 %d アクト　%d 層" % [run.state.act_index + 1, floor_no]

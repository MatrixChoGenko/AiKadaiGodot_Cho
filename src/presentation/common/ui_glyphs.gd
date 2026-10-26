class_name UiGlyphs extends RefCounted
## ⑤ Presentation：図形 ＋ 文字のアイコンの文字と色の対応表（素材なしの方針）と、取り込んだ画像の対応表。
## アイコン画像（StatusData.icon など）が設定されたら、それを優先する側に置き換える想定。

const NODE_GLYPHS: Dictionary[MapNode.Type, String] = {
	MapNode.Type.BATTLE: "戦", MapNode.Type.ELITE: "精", MapNode.Type.BOSS: "ボス",
	MapNode.Type.EVENT: "？", MapNode.Type.SHOP: "店", MapNode.Type.REST: "休", MapNode.Type.TREASURE: "宝",
}

## 画像のあるノードは文字の代わりにこれを描く（無い種類は文字のまま）。素材は CC0（assets/textures/icons の LICENSE）。
const NODE_ICONS: Dictionary[MapNode.Type, Texture2D] = {
	MapNode.Type.BATTLE: preload("res://assets/textures/icons/map_battle.png"),
	MapNode.Type.ELITE: preload("res://assets/textures/icons/map_elite.png"),
	MapNode.Type.BOSS: preload("res://assets/textures/icons/map_boss.png"),
	MapNode.Type.EVENT: preload("res://assets/textures/icons/map_event.png"),
	MapNode.Type.REST: preload("res://assets/textures/icons/map_rest.png"),
	MapNode.Type.SHOP: preload("res://assets/textures/icons/map_shop.png"),
	MapNode.Type.TREASURE: preload("res://assets/textures/icons/map_treasure.png"),
}

const NODE_COLORS: Dictionary[MapNode.Type, Color] = {
	MapNode.Type.BATTLE: Color(0.45, 0.32, 0.3), MapNode.Type.ELITE: Color(0.75, 0.22, 0.2),
	MapNode.Type.BOSS: Color(0.55, 0.08, 0.1), MapNode.Type.EVENT: Color(0.42, 0.3, 0.62),
	MapNode.Type.SHOP: Color(0.72, 0.56, 0.16), MapNode.Type.REST: Color(0.22, 0.55, 0.3),
	MapNode.Type.TREASURE: Color(0.78, 0.45, 0.12),
}

const INTENT_GLYPHS: Dictionary[Intent.Kind, String] = {
	Intent.Kind.ATTACK: "攻", Intent.Kind.ATTACK_DEFEND: "攻", Intent.Kind.ATTACK_DEBUFF: "攻",
	Intent.Kind.DEFEND: "守", Intent.Kind.BUFF: "強", Intent.Kind.DEBUFF: "弱",
	Intent.Kind.SPECIAL: "特", Intent.Kind.SLEEP: "眠", Intent.Kind.UNKNOWN: "？",
}

const INTENT_COLORS: Dictionary[Intent.Kind, Color] = {
	Intent.Kind.ATTACK: Color(0.8, 0.2, 0.18), Intent.Kind.ATTACK_DEFEND: Color(0.8, 0.2, 0.18),
	Intent.Kind.ATTACK_DEBUFF: Color(0.8, 0.2, 0.18), Intent.Kind.DEFEND: Color(0.25, 0.45, 0.8),
	Intent.Kind.BUFF: Color(0.85, 0.55, 0.15), Intent.Kind.DEBUFF: Color(0.45, 0.6, 0.2),
	Intent.Kind.SPECIAL: Color(0.5, 0.4, 0.65), Intent.Kind.SLEEP: Color(0.35, 0.35, 0.45),
	Intent.Kind.UNKNOWN: Color(0.35, 0.35, 0.45),
}

const CARD_TYPE_GLYPHS: Dictionary[CardData.Type, String] = {
	CardData.Type.ATTACK: "剣", CardData.Type.SKILL: "盾", CardData.Type.POWER: "力",
	CardData.Type.STATUS: "状", CardData.Type.CURSE: "呪",
}

## カード面の下の丸 2 つ（種類の記号）の色。
const CARD_TYPE_COLORS: Dictionary[CardData.Type, Color] = {
	CardData.Type.ATTACK: Color(0.62, 0.14, 0.12), CardData.Type.SKILL: Color(0.16, 0.34, 0.62),
	CardData.Type.POWER: Color(0.2, 0.46, 0.24), CardData.Type.STATUS: Color(0.36, 0.36, 0.4),
	CardData.Type.CURSE: Color(0.36, 0.14, 0.4),
}

## カードのフレーム（金属の色 = レアリティ）。tools/card_frames.py が cardframe02 から作る。
const FRAME_BRONZE: Texture2D = preload("res://assets/textures/card_frames/frame_bronze.png")
const RARITY_FRAMES: Dictionary[CardData.Rarity, Texture2D] = {
	CardData.Rarity.STARTER: FRAME_BRONZE, CardData.Rarity.COMMON: FRAME_BRONZE,
	CardData.Rarity.UNCOMMON: preload("res://assets/textures/card_frames/frame_silver.png"),
	CardData.Rarity.RARE: preload("res://assets/textures/card_frames/frame_gold.png"),
	CardData.Rarity.SPECIAL: FRAME_BRONZE,
}

## コストの丸（cardframe02 の energy_orb の輪をフレームの金属の色にしたもの。tools/cost_orbs.py が作る）。
const COST_ORB_BRONZE: Texture2D = preload("res://assets/textures/card_frames/cost_orb_bronze.png")
const RARITY_COST_ORBS: Dictionary[CardData.Rarity, Texture2D] = {
	CardData.Rarity.STARTER: COST_ORB_BRONZE, CardData.Rarity.COMMON: COST_ORB_BRONZE,
	CardData.Rarity.UNCOMMON: preload("res://assets/textures/card_frames/cost_orb_silver.png"),
	CardData.Rarity.RARE: preload("res://assets/textures/card_frames/cost_orb_gold.png"),
	CardData.Rarity.SPECIAL: COST_ORB_BRONZE,
}

## フレームのきらめき（assets/shaders/card_sparkle.gdshader）：きらめきの枠の数 [最小, 最大]（カードごとにこの範囲で決まる）と色。
## 銅 = なし、銀 = 2〜3（冷たい白）、金 = 4（暖かい金）。無いレアリティ = なし。
const RARITY_SPARKLES: Dictionary[CardData.Rarity, Vector2i] = {
	CardData.Rarity.UNCOMMON: Vector2i(2, 3), CardData.Rarity.RARE: Vector2i(4, 4),
}
const RARITY_SPARKLE_COLORS: Dictionary[CardData.Rarity, Color] = {
	CardData.Rarity.UNCOMMON: Color(0.82, 0.92, 1.0), CardData.Rarity.RARE: Color(1.0, 0.8, 0.35),
}

## 意図の画像（tools/icon_sheet.py が AI のシートから切り出す。攻撃 ＋ 防御は短剣と盾の合成）。
const INTENT_ICONS: Dictionary[Intent.Kind, Texture2D] = {
	Intent.Kind.ATTACK: preload("res://assets/textures/icons/intent/attack.png"),
	Intent.Kind.ATTACK_DEFEND: preload("res://assets/textures/icons/intent/attack_defend.png"),
	Intent.Kind.ATTACK_DEBUFF: preload("res://assets/textures/icons/intent/attack_debuff.png"),
	Intent.Kind.DEFEND: preload("res://assets/textures/icons/intent/defend.png"),
	Intent.Kind.BUFF: preload("res://assets/textures/icons/intent/buff.png"),
	Intent.Kind.DEBUFF: preload("res://assets/textures/icons/intent/debuff.png"),
	Intent.Kind.SPECIAL: preload("res://assets/textures/icons/intent/special.png"),
	Intent.Kind.SLEEP: preload("res://assets/textures/icons/intent/sleep.png"),
	Intent.Kind.UNKNOWN: preload("res://assets/textures/icons/intent/unknown.png"),
}

## レリック / ポーション / ステータスの画像のフォルダ（ファイル名 = id。tools/icon_sheet.py が作る）。
## データの icon が設定されていればそちらを優先する。どちらも無ければ null（図形 ＋ 文字のまま）。
const RELIC_ICON_DIR: String = "res://assets/textures/icons/relic/"
const POTION_ICON_DIR: String = "res://assets/textures/icons/potion/"
const STATUS_ICON_DIR: String = "res://assets/textures/icons/status/"

static var _icon_cache: Dictionary[String, Texture2D] = {}

## カードを出したときの光（CardBurst）の色。
const CARD_BURST_COLORS: Dictionary[CardData.Type, Color] = {
	CardData.Type.ATTACK: Color(1.0, 0.62, 0.3), CardData.Type.SKILL: Color(0.45, 0.8, 1.0),
	CardData.Type.POWER: Color(0.85, 0.6, 1.0), CardData.Type.STATUS: Color(0.7, 0.7, 0.75),
	CardData.Type.CURSE: Color(0.6, 0.3, 0.5),
}

const RELIC_COLORS: Dictionary[RelicData.Rarity, Color] = {
	RelicData.Rarity.STARTER: Color(0.5, 0.5, 0.55), RelicData.Rarity.COMMON: Color(0.45, 0.5, 0.55),
	RelicData.Rarity.UNCOMMON: Color(0.25, 0.45, 0.7), RelicData.Rarity.RARE: Color(0.75, 0.55, 0.15),
	RelicData.Rarity.BOSS: Color(0.6, 0.15, 0.2), RelicData.Rarity.SHOP: Color(0.25, 0.55, 0.35),
}

const POTION_COLORS: Dictionary[PotionData.Rarity, Color] = {
	PotionData.Rarity.COMMON: Color(0.3, 0.55, 0.45), PotionData.Rarity.UNCOMMON: Color(0.3, 0.45, 0.75),
	PotionData.Rarity.RARE: Color(0.75, 0.5, 0.15),
}

const BUFF_COLOR: Color = Color(0.25, 0.5, 0.75)
const DEBUFF_COLOR: Color = Color(0.6, 0.25, 0.4)
const NEUTRAL_COLOR: Color = Color(0.4, 0.4, 0.45)
const ENERGY_COLOR: Color = Color(0.9, 0.55, 0.12)
const BLOCK_COLOR: Color = Color(0.3, 0.5, 0.8)

## フローティング数字の色（DamageEffect.Kind ごと + 回復 / ブロック）。
const DAMAGE_COLORS: Dictionary[DamageEffect.Kind, Color] = {
	DamageEffect.Kind.ATTACK: Color(1.0, 0.92, 0.85), DamageEffect.Kind.STATUS: Color(0.6, 0.95, 0.4),
	DamageEffect.Kind.THORNS: Color(1.0, 0.7, 0.3), DamageEffect.Kind.HP_LOSS: Color(1.0, 0.45, 0.45),
}
const HEAL_COLOR: Color = Color(0.45, 1.0, 0.5)
const BLOCK_NUMBER_COLOR: Color = Color(0.55, 0.75, 1.0)


static func relic_icon(data: RelicData) -> Texture2D:
	return data.icon if data.icon != null else _icon_in(RELIC_ICON_DIR, data.id)


static func potion_icon(data: PotionData) -> Texture2D:
	return data.icon if data.icon != null else _icon_in(POTION_ICON_DIR, data.id)


static func status_icon(data: StatusData) -> Texture2D:
	return data.icon if data.icon != null else _icon_in(STATUS_ICON_DIR, data.id)


static func _icon_in(dir: String, id: StringName) -> Texture2D:
	var path := dir + String(id) + ".png"
	if not _icon_cache.has(path):
		_icon_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icon_cache[path]


static func first_char(s: String) -> String:
	return s.substr(0, 1) if not s.is_empty() else "?"


static func status_color(data: StatusData) -> Color:
	match data.polarity:
		StatusData.Polarity.BUFF:
			return BUFF_COLOR
		StatusData.Polarity.DEBUFF:
			return DEBUFF_COLOR
	return NEUTRAL_COLOR


## インテントの数字（攻撃は 1 ヒットのダメージと回数。正確に出せないときは空 = アイコンだけ。GameDesign §1 の柱 2）。
static func intent_label(intent: Intent) -> String:
	if intent.uncertain:
		return ""
	if intent.is_attack():
		return str(intent.damage) if intent.hits <= 1 else "%d×%d" % [intent.damage, intent.hits]
	return ""

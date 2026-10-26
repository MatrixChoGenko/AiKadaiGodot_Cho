@tool
class_name CardData extends Resource
## ② Content：カード定義（GameDesign §6 / Architecture §5.2）。実行時は読み取り専用。
## アップグレード = 別の CardData（upgraded）に差し替える。数値の書き換えではない。
## @tool は Inspector で _validate_property()（関係のないフィールドを隠す）を動かすため。

enum Type { ATTACK, SKILL, POWER, STATUS, CURSE }
enum Rarity { STARTER, COMMON, UNCOMMON, RARE, SPECIAL }
enum CostMode { FIXED, X, UNPLAYABLE }
## キーワードのビット。プレイ不可は CostMode.UNPLAYABLE で表す（KeywordData 側では UNPLAYABLE を持つ）。
enum Keyword { EXHAUST = 1, RETAIN = 2, INNATE = 4, ETHEREAL = 8 }
## プレイ時にプレイヤーが敵を 1 体選ぶ必要があるか。
enum Aim { NONE, ENEMY }

## Type の型フィルタ用ビット（`1 << Type`）。ValueSource / Condition / 効果の type_filter で使う。0 = すべて。
const TYPE_BIT_ATTACK: int = 1 << Type.ATTACK
const TYPE_BIT_SKILL: int = 1 << Type.SKILL
const TYPE_BIT_POWER: int = 1 << Type.POWER
const TYPE_BIT_STATUS: int = 1 << Type.STATUS
const TYPE_BIT_CURSE: int = 1 << Type.CURSE

@export var id: StringName
@export var name: String
@export var art: Texture2D
## 絵の窓（横長）に収まらない上下のどこを見せるか。0 = 上端、0.5 = 中央、1 = 下端。
@export_range(0.0, 1.0, 0.01) var art_focus: float = 0.5
@export_group("Rules")
@export var type: Type = Type.ATTACK
@export var rarity: Rarity = Rarity.COMMON
@export var cost_mode: CostMode = CostMode.FIXED:
	set(value):
		cost_mode = value
		notify_property_list_changed()
@export_range(0, 9) var cost: int = 1
@export var aim: Aim = Aim.NONE
@export_flags("Exhaust", "Retain", "Innate", "Ethereal") var keywords: int = 0
## アップグレード後のカード。null = アップグレード不可。
@export var upgraded: CardData
@export_group("Effects")
@export var on_play: Array[CardEffect] = []
@export var on_draw: Array[CardEffect] = []
## 「手札から捨てられた」ときだけ発動する（プレイ後に捨て札へ行くのは含まない）。
@export var on_discard: Array[CardEffect] = []
## 廃棄されたときは常に発動する（プレイ後の自己廃棄も含む）。
@export var on_exhaust: Array[CardEffect] = []
@export var end_of_turn_in_hand: Array[CardEffect] = []
@export_group("Text")
## 説明文のテンプレート。`{label}` が効果のリアルタイムの数値に置き換わる。
## キーワード（廃棄 / 保留 / 天賦 / エセリアル / プレイ不可）は CardText が自動で付け足すので書かない。
@export_multiline var text: String


func has_keyword(k: Keyword) -> bool:
	return keywords & k != 0


func _validate_property(property: Dictionary) -> void:
	if property["name"] == "cost" and cost_mode != CostMode.FIXED:
		property["usage"] = PROPERTY_USAGE_NO_EDITOR

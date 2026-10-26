class_name PotionData extends Resource
## ② Content：ポーション定義（GameDesign §10）。効果はカードと同じ CardEffect を使う。

enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: StringName
@export var name: String
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export var aim: CardData.Aim = CardData.Aim.NONE
@export var effects: Array[CardEffect] = []
## ショップでの個別価格。0 = RunConfig のレアリティ別の価格を使う。
@export var shop_price: int = 0
## 説明文のテンプレート（カードと同じく `{label}`）。
@export_multiline var text: String

class_name RelicData extends Resource
## ② Content：レリック定義（GameDesign §9）。消えないステータスとして behaviors を持つ。

enum Rarity { STARTER, COMMON, UNCOMMON, RARE, BOSS, SHOP }

@export var id: StringName
@export var name: String
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
## ショップでの個別価格。0 = RunConfig のレアリティ別の価格を使う。
@export var shop_price: int = 0
@export var behaviors: Array[CombatBehavior] = []
@export_multiline var text: String

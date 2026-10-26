class_name RunConfig extends Resource
## ② Content：バランス数値のすべて（GameDesign §13）。数値の調整はこの 1 ファイルだけで行う。
## 重み・価格の配列はレアリティの enum の順番に並べる（例：card_rarity_weights は [COMMON, UNCOMMON, RARE]）。

@export_group("Start")
@export var start_max_hp: int = 80
@export var start_gold: int = 99
@export var energy_per_turn: int = 3
@export var draw_per_turn: int = 5
@export var potion_slots: int = 3
@export var starting_deck: Array[CardData] = []
@export var starting_relics: Array[RelicData] = []

@export_group("Combat")
@export var hand_limit: int = 10
@export var echo_limit: int = 8
## このターン数を超えたら敗北（無限ループ防止）。
@export var turn_limit: int = 200

@export_group("Rewards")
## 報酬ゴールドの範囲 [最小, 最大]：通常 / エリート / ボス。
@export var gold_normal: Vector2i = Vector2i(10, 20)
@export var gold_elite: Vector2i = Vector2i(25, 35)
@export var gold_boss: Vector2i = Vector2i(75, 100)
@export var reward_card_count: int = 3
## [COMMON, UNCOMMON, RARE]
@export var card_rarity_weights: PackedInt32Array = PackedInt32Array([60, 32, 8])
@export var elite_rare_bonus: int = 10
@export var boss_rare_bonus: int = 20
## ポーションのドロップ率（%）：通常 / エリート / ボス。
@export var potion_chance_normal: int = 40
@export var potion_chance_elite: int = 60
@export var potion_chance_boss: int = 100
## [COMMON, UNCOMMON, RARE]
@export var potion_rarity_weights: PackedInt32Array = PackedInt32Array([65, 25, 10])
## エリート / 宝箱 / ショップのレリックのレアリティの重み [COMMON, UNCOMMON, RARE]（GameDesign に記載なし。M1 で仮決め）。
@export var relic_rarity_weights: PackedInt32Array = PackedInt32Array([50, 33, 17])
@export var treasure_gold: Vector2i = Vector2i(25, 50)

@export_group("Shop")
@export var shop_card_count: int = 5
@export var shop_relic_count: int = 2
@export var shop_potion_count: int = 3
## 価格の変動幅（±%）。カードだけに適用する。
@export var shop_card_price_variance: int = 10
## [STARTER(未使用), COMMON, UNCOMMON, RARE, SPECIAL(未使用)]
@export var card_prices: PackedInt32Array = PackedInt32Array([0, 50, 75, 150, 0])
## [STARTER(未使用), COMMON, UNCOMMON, RARE, BOSS, SHOP]
@export var relic_prices: PackedInt32Array = PackedInt32Array([0, 150, 180, 250, 300, 200])
## [COMMON, UNCOMMON, RARE]
@export var potion_prices: PackedInt32Array = PackedInt32Array([50, 75, 100])
@export var removal_price_base: int = 75
@export var removal_price_step: int = 25
@export var upgrade_price_base: int = 100
@export var upgrade_price_step: int = 25

@export_group("Rest And Acts")
## 休憩で回復する最大 HP の割合（%）。
@export var rest_heal_percent: int = 30
## アクト移行で回復する最大 HP の割合（%）。最低 1。
@export var act_heal_percent: int = 30

@export_group("Map")
## ノードの種類の重み [戦闘, イベント, エリート, 休憩, ショップ]。
@export var node_weights: PackedInt32Array = PackedInt32Array([40, 26, 19, 32, 30])
## エリートが出始める行。
@export var elite_min_row: int = 5
## 休憩 / ショップが出始める行。
@export var rest_shop_min_row: int = 3
## この行より前の通常戦闘は、序盤用（EncounterData.early）のエンカウントだけから選ぶ。
@export var early_battle_rows: int = 3
@export var min_shops: int = 2
## 種類の抽選をやり直す上限。超えたら戦闘にする。
@export var node_reroll_limit: int = 8

@export_group("Co-op")
## 協力プレイの敵の HP：1 人増えるごとに +この % （GameDesign §21。2 人 175%、4 人 325%）。
@export var coop_enemy_hp_percent: int = 75
## 協力プレイで戦闘中に倒れた人の、勝利後の HP。
@export var coop_revive_hp: int = 1

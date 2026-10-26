class_name ContentLibrary extends Resource
## ② Content：コンテンツインデックス（Architecture §17.2）。ツール（addons/trycard_tools）が自動生成する。
## 実行時はこの 1 ファイルだけを読み込む。手で編集しない。
## id は種類ごとに一意（敵の slime とエンカウントの slime のように、種類が違えば同じ id でよい）。

@export var cards: Array[CardData] = []
@export var statuses: Array[StatusData] = []
@export var keywords: Array[KeywordData] = []
@export var relics: Array[RelicData] = []
@export var potions: Array[PotionData] = []
@export var enemies: Array[EnemyData] = []
@export var encounters: Array[EncounterData] = []
@export var events: Array[EventData] = []
@export var acts: Array[ActData] = []
@export var config: RunConfig


func card(id: StringName) -> CardData:
	for c in cards:
		if c.id == id:
			return c
	return null


func status(id: StringName) -> StatusData:
	for s in statuses:
		if s.id == id:
			return s
	return null


func relic(id: StringName) -> RelicData:
	for r in relics:
		if r.id == id:
			return r
	return null


func potion(id: StringName) -> PotionData:
	for p in potions:
		if p.id == id:
			return p
	return null


func enemy(id: StringName) -> EnemyData:
	for e in enemies:
		if e.id == id:
			return e
	return null


func encounter(id: StringName) -> EncounterData:
	for e in encounters:
		if e.id == id:
			return e
	return null


func event(id: StringName) -> EventData:
	for e in events:
		if e.id == id:
			return e
	return null


## 報酬 / ショップに出るカード（基本 / 特殊を除く）。
func reward_pool() -> Array[CardData]:
	var pool: Array[CardData] = []
	for c in cards:
		if c.rarity in [CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON, CardData.Rarity.RARE]:
			pool.append(c)
	return pool


## 強化版を除いたカード（ほかのカードの upgraded になっていないもの）。初期・状態異常・呪いも含む。図鑑と「全カードで開始」で使う。
func base_cards() -> Array[CardData]:
	var upgrades := {}
	for c in cards:
		if c.upgraded != null:
			upgrades[c.upgraded] = true
	var result: Array[CardData] = []
	for c in cards:
		if not upgrades.has(c):
			result.append(c)
	return result


func cards_by_rarity(rarity: CardData.Rarity) -> Array[CardData]:
	var result: Array[CardData] = []
	for c in cards:
		if c.rarity == rarity:
			result.append(c)
	return result

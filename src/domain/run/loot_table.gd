class_name LootTable extends RefCounted
## ③ Domain：カード / レリック / ポーションの抽選（GameDesign §12.1、付録 C の C12・C34・C35・C40）。
## 乱数のストリームは呼び出し側が決める（報酬 = reward、ショップ = shop、イベント = event）。
## 候補はコンテンツの並び順のまま使い、Dictionary の順番には依存しない。

const CARD_RARITIES: Array[CardData.Rarity] = [CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON, CardData.Rarity.RARE]
const RELIC_RARITIES: Array[RelicData.Rarity] = [RelicData.Rarity.COMMON, RelicData.Rarity.UNCOMMON, RelicData.Rarity.RARE]
const POTION_RARITIES: Array[PotionData.Rarity] = [PotionData.Rarity.COMMON, PotionData.Rarity.UNCOMMON, PotionData.Rarity.RARE]

var content: ContentLibrary
var config: RunConfig
var rng: RngStreams


func _init(p_content: ContentLibrary, p_config: RunConfig, p_rng: RngStreams) -> void:
	content = p_content
	config = p_config
	rng = p_rng


## レアリティの重み（card_rarity_weights。レアに rare_bonus を足す）でカードを count 枚選ぶ。互いに異なる。
## 選んだレアリティのカードが残っていなければ報酬プール全体から選ぶ。
func roll_cards(stream: StringName, count: int, rare_bonus: int = 0) -> Array[CardData]:
	var weights := config.card_rarity_weights.duplicate()
	if weights.size() > 2:
		weights[2] += rare_bonus
	var picked: Array[CardData] = []
	for i in count:
		var idx := rng.weighted(stream, weights)
		var candidates: Array[CardData] = []
		if idx >= 0 and idx < CARD_RARITIES.size():
			candidates = _without(content.cards_by_rarity(CARD_RARITIES[idx]), picked)
		if candidates.is_empty():
			candidates = _without(content.reward_pool(), picked)
		if candidates.is_empty():
			break
		picked.append(rng.pick(stream, candidates) as CardData)
	return picked


## pool から重みなしで count 枚選ぶ。互いに異なる。
func random_cards(stream: StringName, pool: Array[CardData], count: int) -> Array[CardData]:
	var picked: Array[CardData] = []
	for i in count:
		var candidates := _without(pool, picked)
		if candidates.is_empty():
			break
		picked.append(rng.pick(stream, candidates) as CardData)
	return picked


## relic_rarity_weights（コモン / アンコモン / レア）で 1 つ選ぶ。所持済み・exclude は除く。
## 選んだレアリティが残っていなければ、そのレアリティの重みを 0 にして引き直す。全部無ければ null。
func roll_relic(stream: StringName, owned: Array[RelicData], exclude: Array[RelicData] = []) -> RelicData:
	var weights := config.relic_rarity_weights.duplicate()
	while true:
		var idx := rng.weighted(stream, weights)
		if idx < 0 or idx >= RELIC_RARITIES.size():
			return null
		var r := relic_of_rarity(stream, RELIC_RARITIES[idx], owned, exclude)
		if r != null:
			return r
		weights[idx] = 0
	return null


## 指定のレアリティから 1 つ。無ければ null（代わりを探さない）。
func relic_of_rarity(stream: StringName, rarity: RelicData.Rarity, owned: Array[RelicData],
		exclude: Array[RelicData] = []) -> RelicData:
	var candidates: Array[RelicData] = []
	for r in content.relics:
		if r.rarity == rarity and not owned.has(r) and not exclude.has(r):
			candidates.append(r)
	return rng.pick(stream, candidates) as RelicData


## ボスレリック。全部持っていたら通常のレリックの抽選にする。
func roll_boss_relic(stream: StringName, owned: Array[RelicData]) -> RelicData:
	var r := relic_of_rarity(stream, RelicData.Rarity.BOSS, owned)
	return r if r != null else roll_relic(stream, owned)


## potion_rarity_weights で 1 つ。重複可。
func roll_potion(stream: StringName) -> PotionData:
	var weights := config.potion_rarity_weights.duplicate()
	while true:
		var idx := rng.weighted(stream, weights)
		if idx < 0 or idx >= POTION_RARITIES.size():
			return null
		var candidates: Array[PotionData] = []
		for p in content.potions:
			if p.rarity == POTION_RARITIES[idx]:
				candidates.append(p)
		if not candidates.is_empty():
			return rng.pick(stream, candidates) as PotionData
		weights[idx] = 0
	return null


static func _without(pool: Array[CardData], picked: Array[CardData]) -> Array[CardData]:
	var result: Array[CardData] = []
	for c in pool:
		if not picked.has(c):
			result.append(c)
	return result

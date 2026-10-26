class_name RewardFactory extends RefCounted
## ③ Domain：戦闘報酬 / 宝箱の生成（GameDesign §12.1・§12.2）。乱数は reward ストリーム。
## 行の並び：ゴールド → カード 3 択 → レリック → ポーション。

const STREAM: StringName = &"reward"


static func for_combat(loot: LootTable, rank: EnemyData.Rank, owned: Array[RelicData]) -> Reward:
	var cfg := loot.config
	var reward := Reward.new()
	var gold_range := cfg.gold_normal
	var rare_bonus := 0
	var potion_chance := cfg.potion_chance_normal
	match rank:
		EnemyData.Rank.ELITE:
			gold_range = cfg.gold_elite
			rare_bonus = cfg.elite_rare_bonus
			potion_chance = cfg.potion_chance_elite
		EnemyData.Rank.BOSS:
			gold_range = cfg.gold_boss
			rare_bonus = cfg.boss_rare_bonus
			potion_chance = cfg.potion_chance_boss
	reward.add(RewardItem.of_gold(loot.rng.range_int(STREAM, gold_range.x, gold_range.y)))
	var cards := loot.roll_cards(STREAM, cfg.reward_card_count, rare_bonus)
	if not cards.is_empty():
		reward.add(RewardItem.of_cards(cards))
	var relic: RelicData = null
	match rank:
		EnemyData.Rank.ELITE:
			relic = loot.roll_relic(STREAM, owned)
		EnemyData.Rank.BOSS:
			relic = loot.roll_boss_relic(STREAM, owned)
	if relic != null:
		reward.add(RewardItem.of_relic(relic))
	if loot.rng.chance(STREAM, potion_chance):
		var potion := loot.roll_potion(STREAM)
		if potion != null:
			reward.add(RewardItem.of_potion(potion))
	return reward


## 宝箱：レリック 1 つ + ゴールド。カードはなし。
static func for_treasure(loot: LootTable, owned: Array[RelicData]) -> Reward:
	var cfg := loot.config
	var reward := Reward.new()
	reward.add(RewardItem.of_gold(loot.rng.range_int(STREAM, cfg.treasure_gold.x, cfg.treasure_gold.y)))
	var relic := loot.roll_relic(STREAM, owned)
	if relic != null:
		reward.add(RewardItem.of_relic(relic))
	return reward

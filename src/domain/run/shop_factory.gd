class_name ShopFactory extends RefCounted
## ③ Domain：ショップの在庫と価格（GameDesign §12.3、付録 C の C29・C34）。乱数は shop ストリーム。
## 棚：カード 5 枚（互いに異なる。価格 ±10%）、レリック 2 つ（1 枠目はコモン〜レア、2 枠目はショップ専用。重複なし）、ポーション 3 本（重複可）。

const STREAM: StringName = &"shop"


static func create(loot: LootTable, owned: Array[RelicData]) -> ShopStock:
	var cfg := loot.config
	var stock := ShopStock.new()
	for card in loot.roll_cards(STREAM, cfg.shop_card_count):
		var item := ShopItem.new()
		item.kind = ShopItem.Kind.CARD
		item.card = card
		var pct := loot.rng.range_int(STREAM, -cfg.shop_card_price_variance, cfg.shop_card_price_variance)
		item.price = roundi(_at(cfg.card_prices, card.rarity) * (100 + pct) / 100.0)
		stock.items.append(item)
	var offered: Array[RelicData] = []
	for i in cfg.shop_relic_count:
		var relic: RelicData = null
		if i == 1:
			relic = loot.relic_of_rarity(STREAM, RelicData.Rarity.SHOP, owned, offered)
		if relic == null:
			relic = loot.roll_relic(STREAM, owned, offered)
		if relic == null:
			continue
		offered.append(relic)
		var item := ShopItem.new()
		item.kind = ShopItem.Kind.RELIC
		item.relic = relic
		item.price = relic_price(relic, cfg)
		stock.items.append(item)
	for i in cfg.shop_potion_count:
		var potion := loot.roll_potion(STREAM)
		if potion == null:
			continue
		var item := ShopItem.new()
		item.kind = ShopItem.Kind.POTION
		item.potion = potion
		item.price = potion.shop_price if potion.shop_price > 0 else _at(cfg.potion_prices, potion.rarity)
		stock.items.append(item)
	return stock


static func relic_price(relic: RelicData, cfg: RunConfig) -> int:
	return relic.shop_price if relic.shop_price > 0 else _at(cfg.relic_prices, relic.rarity)


static func removal_price(cfg: RunConfig, bought: int) -> int:
	return cfg.removal_price_base + bought * cfg.removal_price_step


static func upgrade_price(cfg: RunConfig, bought: int) -> int:
	return cfg.upgrade_price_base + bought * cfg.upgrade_price_step


static func _at(table: PackedInt32Array, index: int) -> int:
	return table[index] if index >= 0 and index < table.size() else 0

class_name GainRelicRunEffect extends RunEffect
## レリックを得る。指定、またはレアリティでランダム（所持済みは除外）。ANY は RunConfig.relic_rarity_weights で抽選する。

enum Pool { FIXED, ANY, COMMON, UNCOMMON, RARE, BOSS }

@export var pool: Pool = Pool.ANY
## pool = FIXED のときのレリック。
@export var relic: RelicData


func apply(ctx: RunEffectContext) -> void:
	var owned := ctx.state.owned_relics()
	var data: RelicData = null
	match pool:
		Pool.FIXED:
			data = relic if relic != null and not owned.has(relic) else null
		Pool.ANY:
			data = ctx.loot.roll_relic(RunEffectContext.STREAM, owned)
		Pool.COMMON:
			data = ctx.loot.relic_of_rarity(RunEffectContext.STREAM, RelicData.Rarity.COMMON, owned)
		Pool.UNCOMMON:
			data = ctx.loot.relic_of_rarity(RunEffectContext.STREAM, RelicData.Rarity.UNCOMMON, owned)
		Pool.RARE:
			data = ctx.loot.relic_of_rarity(RunEffectContext.STREAM, RelicData.Rarity.RARE, owned)
		Pool.BOSS:
			data = ctx.loot.relic_of_rarity(RunEffectContext.STREAM, RelicData.Rarity.BOSS, owned)
	if data != null:
		ctx.state.add_relic(data)

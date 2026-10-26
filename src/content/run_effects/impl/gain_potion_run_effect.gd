class_name GainPotionRunEffect extends RunEffect
## ポーションを得る。potion が null なら RunConfig.potion_rarity_weights でランダム。枠がいっぱいなら得られない。

@export var potion: PotionData


func apply(ctx: RunEffectContext) -> void:
	var data := potion if potion != null else ctx.loot.roll_potion(RunEffectContext.STREAM)
	if data != null:
		ctx.state.potions.add(data)   # いっぱいなら失われる（付録 C の C39）

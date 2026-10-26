class_name ResolveEffectAction extends CombatAction
## ③ Domain：効果を 1 つ解決する。対象を決め → apply → 「直前の効果の対象」を更新する。
## 解決の前に現場の席へ切り替える（協力プレイ。1 人プレイでは常に同じ席）。

var effect: CardEffect
var ctx: EffectContext


func _init(p_effect: CardEffect, p_ctx: EffectContext) -> void:
	effect = p_effect
	ctx = p_ctx


func execute(combat: Combat) -> ActionQueue.Step:
	combat.focus_ctx(ctx)
	if effect.target != null:
		ctx.targets = effect.target.resolve(ctx)
	if not effect.can_apply(ctx):
		return ActionQueue.Step.DONE
	effect.apply(ctx)
	if effect.target != null:
		ctx.previous_targets = ctx.targets.duplicate()
	return ActionQueue.Step.DONE

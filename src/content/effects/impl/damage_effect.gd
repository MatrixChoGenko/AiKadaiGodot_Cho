class_name DamageEffect extends CardEffect
## ダメージを与える（GameDesign §7.1 damage）。入り口は Combat.deal_damage() だけ（Architecture §7.7）。

## ATTACK = 筋力 / 弱体 / 脆弱 / トゲの影響を受ける。STATUS = 毒やポーションなど補正を受けないダメージ。
enum Kind { ATTACK, STATUS, THORNS, HP_LOSS }

@export var amount: ValueSource
## ヒット数。null = 1 回。
@export var hits: ValueSource
@export var kind: Kind = Kind.ATTACK
@export var pierce_block: bool = false


func apply(ctx: EffectContext) -> void:
	var base := amount.evaluate(ctx)
	var n := hits.evaluate(ctx) if hits != null else 1
	for i in n:
		for t in ctx.targets.duplicate():
			if not t.is_alive():
				continue
			var calc := DamageCalc.new(base, kind, ctx.source, t)
			calc.pierce_block = pierce_block
			ctx.combat.deal_damage(calc)
			ctx.stats.damage_dealt += calc.hp_lost
			ctx.stats.last_damage = calc.hp_lost
			if calc.killed:
				ctx.stats.kills += 1


func preview(ctx: EffectContext, out: Preview) -> void:
	var base := amount.evaluate(ctx)
	var n := hits.evaluate(ctx) if hits != null else 1
	var value := base
	if ctx.combat != null:
		value = ctx.combat.preview_damage(ctx.source, preview_target(ctx), base, kind)
	out.set_label(label, value, base)
	if not target is SelfTarget:
		out.add_attack(value, n)

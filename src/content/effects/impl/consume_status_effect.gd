class_name ConsumeStatusEffect extends CardEffect
## 対象のステータスのスタックを消費する（起爆。GameDesign §7.1 consumeStatus）。
## 消費した量は解決の統計（CONSUMED_STACKS）に入り、後続の効果が ResolveStatValue で使える。

@export var status: StatusData
## true = すべて消費する。false = 最大 max_amount まで。
@export var consume_all: bool = true
@export_range(0, 999) var max_amount: int = 0


func apply(ctx: EffectContext) -> void:
	for u in units_or_source(ctx):
		var stack := u.statuses.find(status)
		if stack == null:
			continue
		var n := stack.stacks if consume_all else mini(max_amount, stack.stacks)
		ctx.combat.reduce_stacks(stack, n)
		ctx.stats.consumed_stacks += n

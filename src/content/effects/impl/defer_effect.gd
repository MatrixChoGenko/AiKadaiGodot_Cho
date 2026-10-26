class_name DeferEffect extends CardEffect
## コンビネータ：子効果を後のタイミングまで遅らせる（GameDesign §7.1 delayed）。インテントの集計には数えない。

enum Timing { END_OF_THIS_TURN, START_OF_NEXT_TURN }

@export var timing: Timing = Timing.END_OF_THIS_TURN
@export var effects: Array[CardEffect] = []


func apply(ctx: EffectContext) -> void:
	ctx.combat.defer(timing, effects, ctx.child())


func preview(ctx: EffectContext, out: Preview) -> void:
	out.muted += 1   # カードテキストの数値は出すが、インテントには数えない
	for e in effects:
		e.preview(ctx, out)
	out.muted -= 1


func children() -> Array[CardEffect]:
	return effects

@abstract class_name RunEffect extends Resource
## ② Content：ラン中の効果（イベント / 休憩 / ショップ用。GameDesign §7.5）。ステートレス：apply() でメンバ変数に書き込まない。
## RunState の変更は ctx を通す。プレイヤーのカード選択が必要なら ctx.requests に積む。


@abstract func apply(ctx: RunEffectContext) -> void


## 走査用。分岐系は子効果を返す。
func children() -> Array[RunEffect]:
	return []

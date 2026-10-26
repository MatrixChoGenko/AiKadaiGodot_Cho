class_name RemoveCardRunEffect extends RunEffect
## プレイヤーがデッキからカードを選んで削除する（カード選択リクエスト。キャンセル不可）。

@export_range(1, 10) var count: int = 1


func apply(ctx: RunEffectContext) -> void:
	ctx.requests.append(RunChoiceRequest.remove(count))

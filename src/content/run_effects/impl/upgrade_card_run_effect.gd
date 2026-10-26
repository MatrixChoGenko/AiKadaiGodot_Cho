class_name UpgradeCardRunEffect extends RunEffect
## プレイヤーがアップグレード可能なカードを選んでアップグレードする（カード選択リクエスト。キャンセル不可）。

@export_range(1, 10) var count: int = 1


func apply(ctx: RunEffectContext) -> void:
	ctx.requests.append(RunChoiceRequest.upgrade(count))

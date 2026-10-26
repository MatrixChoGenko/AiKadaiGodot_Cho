class_name HasUpgradableCardRunCondition extends RunCondition
## アップグレードできるカードがデッキにある。休憩の「鍛える」とアップグレード系の選択肢の可否に使う。


func _test(ctx: RunEffectContext) -> bool:
	return not ctx.state.deck.upgradable().is_empty()

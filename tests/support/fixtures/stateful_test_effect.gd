class_name StatefulTestEffect extends CardEffect
## テスト用：ステートレスのルール違反（エクスポートされていないメンバ変数）を持つ効果。バリデータが検出できることの確認に使う。

var counter: int = 0


func apply(_ctx: EffectContext) -> void:
	counter += 1

class_name EffectContext extends RefCounted
## ③ Domain：効果 1 回の解決の現場（Architecture §6.5）。同じカードの兄弟の効果どうしで共有する
## （直前の効果の対象を PreviousTargets で使うため）。コンビネータは child() で複製する。

const MAX_DEPTH: int = 8

## 現場は Combat のキューや遅延効果の中に保存されるので、循環参照にならないよう弱参照で持つ。
var combat: Combat:
	get:
		return _combat_ref.get_ref() as Combat if _combat_ref != null else null
	set(value):
		_combat_ref = weakref(value) if value != null else null
## 発動者。
var source: Combatant
## プレイヤーが選んだ対象（敵の行動ではプレイヤー）。
var chosen: Combatant
## 元のカード（ポーション / 敵の行動 / ステータスでは null）。
var card: Card
## X コストで実際に支払った量。
var x: int = 0
var repeat_index: int = 0
## 現在の効果で解決された対象。
var targets: Array[Combatant] = []
var previous_targets: Array[Combatant] = []
## 解決全体の統計（child() でも共有）。
var stats: ResolveStats = ResolveStats.new()
## true = プレビュー。状態の変更・イベント・乱数をすべて禁止する。
var preview: bool = false
var depth: int = 0

var _combat_ref: WeakRef


func child() -> EffectContext:
	var c := EffectContext.new()
	c.combat = combat
	c.source = source
	c.chosen = chosen
	c.card = card
	c.x = x
	c.repeat_index = repeat_index
	c.targets = targets.duplicate()
	c.previous_targets = previous_targets.duplicate()
	c.stats = stats
	c.preview = preview
	c.depth = depth + 1
	return c


## 「対象」として読む 1 体：解決済みの対象の先頭、無ければ選んだ対象。
func current_target() -> Combatant:
	for t in targets:
		if t.is_alive():
			return t
	return chosen

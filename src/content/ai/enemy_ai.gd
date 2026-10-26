@abstract class_name EnemyAI extends Resource
## ② Content：敵の行動選択の Strategy（Architecture §9）。ステートレス。実行時の状態は unit.mind（EnemyMind）が持つ。


## このターンの行動を選ぶ。判定はプレビューの現場で行い、乱数は enemy_ai ストリームだけを使う。
@abstract func choose_move(unit: Combatant, combat: Combat) -> EnemyMove


## ダメージを受けた後のフェーズ（1 始まり）。変わらなければ unit.mind.phase を返す。
func phase_after_damage(unit: Combatant) -> int:
	return unit.mind.phase


## フェーズが変わったときに呼ばれる。
func on_phase_changed(_unit: Combatant, _combat: Combat, _phase: int) -> void:
	pass

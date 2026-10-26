class_name ScriptedAI extends EnemyAI
## 既定の AI（Architecture §9.2）。ほぼすべての敵をデータだけで表す。
## 決定の順番：1) 強制（priority > 0 かつ forced_when が成立）→ 2) 固定シーケンス（opening）→ 3) 重み付きランダム。
## 複数フェーズ：HP の % が phase_thresholds を下回るたびに次のフェーズへ進み、phase_change_effects を実行する。

## 固定シーケンス（行動の id の列）。クールダウン / 回数制限の影響を受けない。
@export var opening: Array[StringName] = []
## true なら opening を最後までやったら先頭に戻る（重み付きランダムは使わない）。
@export var loop_opening: bool = false
## フェーズの境目（HP の %、大きい順）。例：[50] = HP 50% 未満で第 2 フェーズ。
@export var phase_thresholds: PackedInt32Array = PackedInt32Array()
## フェーズが変わったときに自分を発動者として実行する効果。
@export var phase_change_effects: Array[CardEffect] = []


func choose_move(unit: Combatant, combat: Combat) -> EnemyMove:
	var mind := unit.mind
	var moves := unit.data.moves
	var ctx := combat.make_preview_context(unit, combat.lead_player(), null)

	# 1) 強制
	var forced: EnemyMove = null
	for m in moves:
		if m.priority > 0 and m.forced_when != null and _usable(m, mind, ctx) and m.forced_when.test(ctx):
			if forced == null or m.priority > forced.priority:
				forced = m
	if forced != null:
		return forced

	# 2) 固定シーケンス
	if mind.sequence_step < opening.size():
		var step_id := opening[mind.sequence_step]
		mind.sequence_step += 1
		if loop_opening and mind.sequence_step >= opening.size():
			mind.sequence_step = 0
		var m := _find(moves, step_id)
		if m != null:
			return m

	# 3) 重み付きランダム
	var candidates: Array[EnemyMove] = []
	var weights := PackedInt32Array()
	for m in moves:
		if not _usable(m, mind, ctx):
			continue
		var w := m.weight
		if m.bonus_when != null and m.bonus_when.test(ctx):
			w += m.bonus_weight
		if w > 0:
			candidates.append(m)
			weights.append(w)
	if candidates.is_empty():
		for m in moves:
			if _usable(m, mind, ctx):
				return m
		return moves[0] if not moves.is_empty() else null
	return candidates[combat.rng.weighted(&"enemy_ai", weights)]


func phase_after_damage(unit: Combatant) -> int:
	var phase := unit.mind.phase
	while phase - 1 < phase_thresholds.size() and unit.hp * 100 < unit.max_hp * phase_thresholds[phase - 1]:
		phase += 1
	return phase


func on_phase_changed(unit: Combatant, combat: Combat, _phase: int) -> void:
	combat.push_effects(phase_change_effects, combat.make_context(unit, combat.lead_player(), null))


func _usable(m: EnemyMove, mind: EnemyMind, ctx: EffectContext) -> bool:
	if m.phases != 0 and m.phases & (1 << (mind.phase - 1)) == 0:
		return false
	if m.max_in_a_row > 0 and mind.trailing_count(m.id) >= m.max_in_a_row:
		return false
	if mind.cooldowns.has(m.id):
		return false
	if m.max_uses > 0 and mind.uses.get(m.id, 0) >= m.max_uses:
		return false
	if m.usable_when != null and not m.usable_when.test(ctx):
		return false
	return true


static func _find(moves: Array[EnemyMove], move_id: StringName) -> EnemyMove:
	for m in moves:
		if m.id == move_id:
			return m
	return null

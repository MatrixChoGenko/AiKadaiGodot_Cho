extends GutTest
## 敵 AI（GameDesign §11.1 / Architecture §9）とインテント。

const T = preload("res://tests/support/builders/content_kit.gd")


func _moves_over(h: CombatHarness, turns: int, index: int = 0) -> Array[StringName]:
	for i in turns:
		h.end_turn()
	return h.enemy(index).mind.history


func test_opening_loops() -> void:
	var e := T.enemy(&"slime", 100, [T.move(&"bite", [T.dmg(1)]), T.move(&"spit", [T.block(1)])], [&"bite", &"bite", &"spit"], true)
	var h := CombatBuilder.new().with_hand([T.filler()]).with_enemy(e).build()
	assert_eq(_moves_over(h, 6), [&"bite", &"bite", &"spit", &"bite", &"bite", &"spit"] as Array[StringName])


func test_opening_then_weighted_with_limits() -> void:
	var e := T.enemy(&"cultist", 200, [
		T.move(&"ritual", [T.apply(&"strength", 1, T.me())], {weight = 0, max_uses = 1}),
		T.move(&"lash", [T.dmg(1)], {weight = 100}),
	], [&"ritual"])
	var h := CombatBuilder.new().with_hand([T.filler()]).with_enemy(e).build()
	var history := _moves_over(h, 5)
	assert_eq(history[0], &"ritual")
	assert_eq(history.count(&"ritual"), 1)


func test_max_in_a_row() -> void:
	var e := T.enemy(&"worm", 200, [
		T.move(&"chomp", [T.dmg(1)], {weight = 99, max_in_a_row = 2}),
		T.move(&"rest", [T.block(1)], {weight = 1}),
	])
	var h := CombatBuilder.new().with_hand([T.filler()]).with_enemy(e).build()
	var history := _moves_over(h, 30)
	for i in range(2, history.size()):
		assert_false(history[i] == &"chomp" and history[i - 1] == &"chomp" and history[i - 2] == &"chomp", "3 連続しない")


func test_forced_move_and_phase_change() -> void:
	var forced := BlockAtLeastCondition.new()
	forced.on = ValueSource.On.TARGET
	forced.value = 20
	var e := T.enemy(&"guardian", 100, [
		T.move(&"slam", [T.dmg(1)], {phases = 1}),
		T.move(&"fury", [T.dmg(1)], {phases = 2}),
		T.move(&"doom", [T.dmg(2)], {phases = 2, priority = 1, forced_when = forced, weight = 0}),
	])
	var ai := e.ai as ScriptedAI
	ai.phase_thresholds = PackedInt32Array([50])
	var cleanse := RemoveStatusesEffect.new()
	cleanse.target = T.me()
	ai.phase_change_effects.assign([cleanse, T.apply(&"strength", 5, T.me())])
	var big_hit := T.card(&"big", 0, [T.dmg(60)], {type = CardData.Type.ATTACK})
	var shield := T.card(&"shield", 0, [T.block(25)])
	var h := CombatBuilder.new().with_hand([T.card(&"w", 0, [T.apply(&"weak", 1)]), big_hit, shield]) \
		.with_enemy(e).with_draw_per_turn(3).build()
	h.play(&"w")
	h.play(&"big")
	assert_eq(h.enemy().mind.phase, 2, "HP 50% 未満で第 2 フェーズ")
	assert_eq(h.stacks(h.enemy(), &"weak"), 0, "フェーズ移行でデバフ解除")
	assert_eq(h.stacks(h.enemy(), &"strength"), 5)
	h.play(&"shield")
	h.end_turn()   # 今回の行動は第 1 フェーズで選んだもの。次のインテントは第 2 フェーズから選ぶ
	h.player().block = 30
	h.combat.choose_intents()
	assert_eq(h.enemy().mind.current_move.id, &"doom", "プレイヤーのブロック ≥ 20 なら強制")


func test_intent_reflects_modifiers() -> void:
	var e := T.enemy(&"hitter", 100, [T.move(&"hit", [T.dmg(10, null, 2)])])
	var h := CombatBuilder.new().with_hand([T.card(&"w", 0, [T.apply(&"weak", 1)])]).with_enemy(e).build()
	var before := h.ctl.intent_of(h.enemy())
	assert_eq(before.kind, Intent.Kind.ATTACK)
	assert_eq(before.damage, 10)
	assert_eq(before.hits, 2)
	h.play(&"w")
	assert_eq(h.ctl.intent_of(h.enemy()).damage, 7, "弱体で数字だけ再計算（行動は選び直さない）")
	assert_eq(h.enemy().mind.current_move.id, &"hit")


func test_intent_kinds() -> void:
	var e := T.enemy(&"x", 100, [T.move(&"thrash", [T.dmg(7), T.block(5)])])
	var h := CombatBuilder.new().with_hand([T.filler()]).with_enemy(e).build()
	var i := h.ctl.intent_of(h.enemy())
	assert_eq(i.kind, Intent.Kind.ATTACK_DEFEND)
	assert_eq(i.block, 5)

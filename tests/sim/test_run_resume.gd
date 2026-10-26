extends GutTest
## M3 受け入れ：任意のチェックポイントでセーブ → ロード → 続行した結果が、中断しなかった場合と完全に一致する。
## 2 つのラン（正式コンテンツ 1 アクト / テスト用 3 アクト）の**すべての**チェックポイントから続行して比べる。


func test_resume_from_every_checkpoint_matches_uninterrupted_run() -> void:
	var official := OfficialSetup.library()
	var cases: Array = [
		[official, null, 21],
		[RunFixtures.multi_act_library(official, 3), RunFixtures.tough_config(official.config), 34],
	]
	var all_reasons: Dictionary = {}
	for c: Array in cases:
		var rec := RunRecorder.new(c[0], c[1]).record(c[2])
		assert_false(rec.outcome["hung"], "run hung: " + rec.bot.failure)
		assert_eq(rec.roundtrip_failures.size(), 0, "\n".join(rec.roundtrip_failures))
		var mismatches := PackedStringArray()
		for i in rec.snapshots.size():
			var resumed := rec.resume_from(i)
			if resumed != rec.final_json:
				mismatches.append("#%d (%s)" % [i, rec.snapshots[i][0]])
			all_reasons[rec.snapshots[i][0]] = true
		gut.p("seed %d: %d checkpoints, final %s, act %d" % [c[2], rec.snapshots.size(),
				RunPhase.Id.keys()[rec.final_phase()], rec.act_reached() + 1])
		assert_eq(mismatches.size(), 0, "resume differs from the uninterrupted run at: " + ", ".join(mismatches))
	for reason: StringName in [RunController.CP_NODE_ENTERED, RunController.CP_COMBAT_STARTED,
			RunController.CP_REWARD_GENERATED, RunController.CP_RETURNED_TO_MAP]:
		assert_true(all_reasons.has(reason), "checkpoint %s was exercised" % reason)


func test_resume_rebuilds_each_phase_identically() -> void:
	# ノードに入った直後のセーブから再開すると、ショップ / イベント / 宝箱 / 戦闘の初手が同じになる（再抽選できない）。
	var lib := OfficialSetup.library()
	for type: MapNode.Type in [MapNode.Type.SHOP, MapNode.Type.TREASURE, MapNode.Type.EVENT, MapNode.Type.BATTLE]:
		var run := RunFixtures.new_run(lib, 8)
		var content_id: StringName = &"shrine_of_blood" if type == MapNode.Type.EVENT else (&"jawworm" if type == MapNode.Type.BATTLE else &"")
		var id := RunFixtures.force_next(run, type, content_id)
		var saved: Array[String] = []
		var grab := func(_r: StringName) -> void: saved.append(RunFixtures.dump(run.state))
		run.checkpoint_reached.connect(grab)
		run.enter_node(id)
		run.checkpoint_reached.disconnect(grab)
		var first := _describe_phase(run)
		for attempt in 2:
			var again := RunController.new(lib)
			again.resume(RunSerializer.new().from_dict(JSON.parse_string(saved[0]) as Dictionary, lib))
			assert_eq(again.state.phase, run.state.phase)
			assert_eq(_describe_phase(again), first, "phase %s rebuilt differently" % RunPhase.Id.keys()[run.state.phase])


func _describe_phase(run: RunController) -> String:
	var s := run.state
	match s.phase:
		RunPhase.Id.SHOP:
			return str(s.shop.items.map(func(i: ShopItem) -> String: return "%s:%d" % [i.content_id(), i.price]))
		RunPhase.Id.TREASURE:
			return str(s.pending_reward.items.map(func(i: RewardItem) -> String: return "%d:%s" % [i.gold, i.relic.id if i.relic else &""]))
		RunPhase.Id.EVENT:
			run.choose_event_option(0)
			return "%s %s %s" % [s.event.id, s.hp, run.request_candidates().map(func(c: CardData) -> StringName: return c.id)]
		RunPhase.Id.COMBAT:
			var c := run.combat.combat
			return "%s %s %s" % [c.piles.hand.map(func(x: Card) -> String: return str(x)),
					c.enemies.map(func(e: Combatant) -> int: return e.hp), c.enemies.map(func(e: Combatant) -> int: return run.combat.intent_of(e).kind)]
	return ""

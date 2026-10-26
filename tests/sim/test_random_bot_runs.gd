extends GutTest
## M3 受け入れ：RandomBot（RunBot）がヘッドレスで 200 ランをエラー 0 で完走する。
## ショップでの購入、イベントの選択、休憩、アクト移行を含む。正式コンテンツ（1 アクト）と、アクト移行を通すための
## テスト用 3 アクト構成を混ぜる：i % 4 == 0 は正式コンテンツ、== 1 は 3 アクト + HP を大きくして後半のアクトまで届かせる、
## それ以外は 3 アクト（通常の HP）。
## あわせて：各チェックポイントのセーブの往復一致、一部のランでの「途中から再開 == 中断なし」、コンテンツ Resource の不変。
## ランの数は環境変数 TRYCARD_SIM_RUNS で変えられる（既定 200）。

const DEFAULT_RUNS: int = 200
## この間隔のランで、途中のチェックポイント 1 つから再開して最終状態を比べる。
const RESUME_EVERY: int = 5   # 5 と 4 は互いに素なので、正式 / 頑丈 / 通常のどの構成も再開の検査を受ける


func test_random_bot_runs() -> void:
	var official := OfficialSetup.library()
	var before := ContentSnapshot.take(official)
	var multi := RunFixtures.multi_act_library(official, 3)
	var tough := RunFixtures.tough_config(official.config)
	var count := int(OS.get_environment("TRYCARD_SIM_RUNS")) if OS.has_environment("TRYCARD_SIM_RUNS") else DEFAULT_RUNS
	var started := Time.get_ticks_msec()
	var totals: Dictionary = {}
	var outcomes: Dictionary = {}
	var reasons: Dictionary = {}
	var hung := PackedStringArray()
	var roundtrip := PackedStringArray()
	var resume_mismatches := PackedStringArray()
	var resumes := 0
	var max_act := 0

	for i in count:
		var lib := official if i % 4 == 0 else multi
		var cfg: RunConfig = tough if i % 4 == 1 else null
		var rec := RunRecorder.new(lib, cfg).record(5000 + i)
		if rec.outcome["hung"]:
			hung.append("run %d: %s" % [i, rec.bot.failure])
		for f in rec.roundtrip_failures:
			roundtrip.append("run %d %s" % [i, f])
		for k: String in rec.bot.stats:
			totals[k] = int(totals.get(k, 0)) + int(rec.bot.stats[k])
		for r: StringName in rec.reasons:
			reasons[r] = int(reasons.get(r, 0)) + int(rec.reasons[r])
		var phase: String = RunPhase.Id.keys()[rec.final_phase()]
		outcomes[phase] = int(outcomes.get(phase, 0)) + 1
		max_act = maxi(max_act, rec.act_reached() + 1)
		if i % RESUME_EVERY == 0 and not rec.snapshots.is_empty():
			var k := (i * 7919 + 13) % rec.snapshots.size()
			resumes += 1
			if rec.resume_from(k) != rec.final_json:
				resume_mismatches.append("run %d checkpoint #%d (%s)" % [i, k, rec.snapshots[k][0]])

	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	gut.p("%d runs in %.1fs: %s, max act %d" % [count, seconds, outcomes, max_act])
	gut.p("stats: %s" % totals)
	gut.p("checkpoints: %s, resumes checked: %d" % [reasons, resumes])
	assert_eq(hung.size(), 0, "hung runs:\n" + "\n".join(hung.slice(0, 10)))
	assert_eq(roundtrip.size(), 0, "save round trip:\n" + "\n".join(roundtrip.slice(0, 10)))
	assert_eq(resume_mismatches.size(), 0, "resume != uninterrupted:\n" + "\n".join(resume_mismatches.slice(0, 10)))
	assert_eq(int(outcomes.get("VICTORY", 0)) + int(outcomes.get("DEFEAT", 0)), count, "every run finished")
	assert_gt(int(totals.get("shop_buys", 0)), 0, "shop purchases happened")
	assert_gt(int(totals.get("removals", 0)), 0, "card removals happened")
	assert_gt(int(totals.get("events", 0)), 0, "event choices happened")
	assert_gt(int(totals.get("requests", 0)), 0, "event card requests happened")
	assert_gt(int(totals.get("rests", 0)), 0, "rests happened")
	assert_gt(int(totals.get("treasures", 0)), 0, "treasures happened")
	assert_gt(int(totals.get("act_transitions", 0)), 0, "act transitions happened")
	assert_gt(int(outcomes.get("VICTORY", 0)), 0, "some runs won")
	assert_eq(max_act, 3, "the last act was reached")
	assert_eq(ContentSnapshot.take(official), before, "content resources were modified during runs")

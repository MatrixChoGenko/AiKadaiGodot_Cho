extends GutTest
## M2 受け入れ：RandomBot で正式コンテンツの戦闘を 1000 戦し、クラッシュ 0・ハング 0。
## あわせて不変条件を検査する（Architecture §18.3）：
##   - プレビュー（カードテキスト・プレイ可否・インテント）が乱数に触れない
##   - インテントの数字 == 実際に受けるダメージ
##   - カード枚数の保存
##   - 戦闘の後もコンテンツ Resource が変わっていない
## 戦闘の数は環境変数 TRYCARD_SIM_COMBATS で変えられる（既定 1000）。

const DEFAULT_COMBATS: int = 1000


func test_random_bot_combats_and_invariants() -> void:
	var lib := OfficialSetup.library()
	var names := CardText.keyword_names_of(lib.keywords)
	var before := ContentSnapshot.take(lib)
	var count := int(OS.get_environment("TRYCARD_SIM_COMBATS")) if OS.has_environment("TRYCARD_SIM_COMBATS") else DEFAULT_COMBATS
	var started := Time.get_ticks_msec()
	var hung := 0
	var aborted := 0
	var victories := 0
	var turns := 0
	var preview_violations := PackedStringArray()
	var conservation_violations := PackedStringArray()
	var intent_mismatches := PackedStringArray()
	var intent_hits := 0

	for i in count:
		var setup := OfficialSetup.random_combat(lib, 1000 + i)
		var deck_size := setup.deck.size()
		var ctl := CombatController.begin(setup)
		var auditor := IntentAuditor.new(ctl)
		var bot := RandomBot.new(i)
		var step := [0]
		bot.on_idle = func() -> void:
			step[0] += 1
			var combat := ctl.combat
			var all := combat.piles.all_cards()
			if all.size() != deck_size + combat.created_count:
				conservation_violations.append("combat %d step %d: %d cards, expected %d" % [i, step[0], all.size(), deck_size + combat.created_count])
			if step[0] % 3 != 0:
				return
			var rng_before := combat.rng.save()
			var version_before := combat.version
			for card in combat.piles.hand:
				ctl.card_text(card, null, names)
				for e in combat.alive_enemies():
					ctl.card_text(card, e, names)
					ctl.check_card(card, e)
				ctl.check_card(card, null)
			for e in combat.alive_enemies():
				ctl.intent_of(e)
			if combat.rng.save() != rng_before or combat.version != version_before:
				preview_violations.append("combat %d step %d" % [i, step[0]])
		var outcome := bot.play(ctl)
		if outcome["hung"]:
			hung += 1
		var r := ctl.result()
		if r.aborted or ctl.combat.queue.runaway:
			aborted += 1
		if r.victory:
			victories += 1
		turns += r.turns
		intent_mismatches.append_array(auditor.mismatches)
		intent_hits += auditor.checked_hits

	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	gut.p("%d combats in %.1fs: %d victories, avg %.1f turns, %d intent hits checked" % [count, seconds, victories, float(turns) / count, intent_hits])
	assert_eq(hung, 0, "hung combats")
	assert_eq(aborted, 0, "aborted combats (ActionQueue runaway)")
	assert_eq(preview_violations.size(), 0, "preview touched rng / emitted events:\n" + "\n".join(preview_violations.slice(0, 10)))
	assert_eq(conservation_violations.size(), 0, "card conservation:\n" + "\n".join(conservation_violations.slice(0, 10)))
	assert_eq(intent_mismatches.size(), 0, "intent != actual:\n" + "\n".join(intent_mismatches.slice(0, 10)))
	assert_gt(intent_hits, 0)
	assert_eq(ContentSnapshot.take(lib), before, "content resources were modified during combat")

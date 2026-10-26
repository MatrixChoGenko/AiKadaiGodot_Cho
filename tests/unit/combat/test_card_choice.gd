extends GutTest
## 戦闘中のカード選択：一時停止と再開（GameDesign §5.9 / Architecture §7.10）。

const T = preload("res://tests/support/builders/content_kit.gd")
const A := ChooseCardsEffect.Action


func _purge() -> CardData:
	return T.card(&"purge", 0, [T.choose(Pile.Id.HAND, A.EXHAUST, 1), T.draw(1)])


func test_pauses_and_resumes_after_choice() -> void:
	var h := CombatBuilder.new().with_hand([_purge(), T.filler(&"a"), T.filler(&"b")]) \
		.with_draw_pile([T.filler(&"c")]).with_draw_per_turn(3).build()
	h.play(&"purge")
	assert_not_null(h.ctl.pending_choice(), "選択待ちで止まる")
	assert_eq(h.hand_ids().size(), 2, "後続の「1 枚引く」はまだ実行されない")
	assert_eq(h.ctl.check_card(h.card(&"a")).reason, PlayResult.WAITING_FOR_CHOICE)
	assert_false(h.end_turn())
	assert_true(h.choose([&"a"]))
	assert_null(h.ctl.pending_choice())
	assert_eq(h.combat.piles.exhaust.size(), 1)
	assert_eq(h.hand_ids(), [&"b", &"c"] as Array[StringName], "再開して 1 枚引いた")


func test_rejects_invalid_answers() -> void:
	var h := CombatBuilder.new().with_hand([_purge(), T.filler(&"a"), T.filler(&"b")]).build()
	h.play(&"purge")
	var choice := h.ctl.pending_choice()
	var outsider: Array[Card] = [Card.new(999, T.filler())]
	assert_false(h.ctl.submit_choice(outsider), "候補外")
	var none: Array[Card] = []
	assert_false(h.ctl.submit_choice(none), "枚数不足")
	var two: Array[Card] = [choice.candidates[0], choice.candidates[1]]
	assert_false(h.ctl.submit_choice(two), "枚数超過")
	assert_not_null(h.ctl.pending_choice())


func test_auto_selects_when_no_real_choice() -> void:
	var h := CombatBuilder.new().with_hand([_purge(), T.filler(&"only")]).build()
	h.play(&"purge")
	assert_null(h.ctl.pending_choice(), "候補が 1 枚だけなら選ばせない")
	assert_eq(h.combat.piles.exhaust.size(), 1)


func test_no_candidates_skips() -> void:
	var h := CombatBuilder.new().with_hand([_purge()]).build()
	h.play(&"purge")
	assert_null(h.ctl.pending_choice())


func test_non_interactive_never_waits() -> void:
	var h := CombatBuilder.new().with_hand([_purge(), T.filler(&"a"), T.filler(&"b")]).interactive(false).build()
	h.play(&"purge")
	assert_null(h.ctl.pending_choice())
	assert_eq(h.combat.piles.exhaust.size(), 1)


func test_allow_fewer_accepts_zero() -> void:
	var hoard := T.card(&"hoard", 0, [T.choose(Pile.Id.HAND, A.DISCARD, 2, true)])
	var h := CombatBuilder.new().with_hand([hoard, T.filler(&"a"), T.filler(&"b"), T.filler(&"c")]).build()
	h.play(&"hoard")
	assert_true(h.choose([]))
	assert_eq(h.hand().size(), 3)


func test_cards_affected_feeds_later_effects() -> void:
	var scav := T.card(&"scav", 0, [T.choose(Pile.Id.HAND, A.DISCARD, 1, true),
		T.block(T.scaled(0, 8, T.stat(ResolveStatValue.Stat.CARDS_AFFECTED)))])
	var h := CombatBuilder.new().with_hand([scav, T.filler(&"a"), T.filler(&"b")]).build()
	h.play(&"scav")
	h.choose([&"a"])
	assert_eq(h.player().block, 8)


func test_retain_this_turn() -> void:
	var hold := T.card(&"hold", 0, [T.choose(Pile.Id.HAND, A.RETAIN, 1)])
	var h := CombatBuilder.new().with_hand([hold, T.filler(&"a"), T.filler(&"b")]).with_draw_per_turn(0).build()
	h.play(&"hold")
	h.choose([&"a"])
	h.end_turn()
	assert_eq(h.hand_ids(), [&"a"] as Array[StringName])


func test_recall_from_discard() -> void:
	var recall := T.card(&"recall", 0, [T.choose(Pile.Id.DISCARD, A.TO_HAND, 1)])
	var h := CombatBuilder.new().with_hand([T.filler(&"a"), recall, T.filler(&"b")]).build()
	h.play(&"a")
	h.play(&"recall")
	assert_true(h.hand_ids().has(&"a"), "捨て札が 1 枚だけなので自動で戻る")
	assert_true(h.cards_conserved())

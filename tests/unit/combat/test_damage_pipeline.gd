extends GutTest
## ダメージパイプライン（GameDesign §5.6 / Architecture §7.7）。

const T = preload("res://tests/support/builders/content_kit.gd")


func _h(hand: Array, enemy: EnemyData = null) -> CombatHarness:
	return CombatBuilder.new().with_hand(hand).with_enemy(enemy if enemy else T.dummy(100)).build()


func test_basic_attack() -> void:
	var h := _h([T.strike(6)])
	assert_true(h.play(&"strike").ok)
	assert_eq(h.enemy().hp, 94)
	assert_eq(h.combat.turn.energy, 2)


func test_strength_adds_flat() -> void:
	var h := _h([T.strike(6)])
	h.add_status(h.player(), &"strength", 3)
	h.play(&"strike")
	assert_eq(h.enemy().hp, 91)


func test_weak_then_vulnerable_truncate_toward_zero() -> void:
	var h := _h([T.strike(6)])
	h.add_status(h.player(), &"weak", 1)
	h.add_status(h.enemy(), &"vulnerable", 1)
	h.play(&"strike")
	assert_eq(h.enemy().hp, 100 - 6, "6 × 0.75 = 4（切り捨て）→ × 1.5 = 6")


func test_strength_before_multiplier() -> void:
	var h := _h([T.strike(6)])
	h.add_status(h.player(), &"strength", 2)
	h.add_status(h.enemy(), &"vulnerable", 1)
	h.play(&"strike")
	assert_eq(h.enemy().hp, 100 - 12, "(6 + 2) × 1.5")


func test_block_absorbs_then_hp() -> void:
	var h := _h([T.strike(10)])
	h.enemy().block = 4
	h.play(&"strike")
	assert_eq(h.enemy().block, 0)
	assert_eq(h.enemy().hp, 94)
	assert_eq(h.events_of(CombatEvent.Kind.BLOCKED).size(), 1)


func test_zero_base_damage_does_nothing_even_with_strength() -> void:
	var zero := T.card(&"zero", 0, [T.dmg(0)], {type = CardData.Type.ATTACK})
	var h := _h([zero])
	h.add_status(h.player(), &"strength", 5)
	h.play(&"zero")
	assert_eq(h.enemy().hp, 100)


func test_status_damage_ignores_strength() -> void:
	var e := T.dmg(10)
	e.kind = DamageEffect.Kind.STATUS
	var h := _h([T.card(&"burn_it", 0, [e])])
	h.add_status(h.player(), &"strength", 5)
	h.play(&"burn_it")
	assert_eq(h.enemy().hp, 90)


func test_preview_matches_actual() -> void:
	var h := _h([T.strike(7)])
	h.add_status(h.player(), &"strength", 2)
	h.add_status(h.player(), &"weak", 1)
	h.add_status(h.enemy(), &"vulnerable", 2)
	var shown := h.combat.preview_damage(h.player(), h.enemy(), 7, DamageEffect.Kind.ATTACK)
	h.play(&"strike")
	assert_eq(100 - h.enemy().hp, shown)


func test_thorns_retaliates_only_attacks() -> void:
	var poison_self := T.card(&"hp_loss", 0, [T.lose_hp(1)])
	var h := _h([T.strike(6), poison_self])
	h.add_status(h.enemy(), &"thorns", 3)
	h.play(&"strike")
	assert_eq(h.player().hp, 77, "攻撃したら 3 返ってくる")
	h.play(&"hp_loss")
	assert_eq(h.player().hp, 76, "自分の HP 喪失には反撃しない")


func test_revive_prevents_death_once() -> void:
	var h := _h([T.strike(50)], T.dummy(20))
	h.add_status(h.enemy(), &"revive", 1)
	h.play(&"strike")
	assert_eq(h.enemy().hp, 11, "HP 1 で踏みとどまって 10 回復")
	assert_true(h.enemy().is_alive())
	assert_eq(h.stacks(h.enemy(), &"revive"), 0)


func test_lethal_and_overkill_flags_and_death() -> void:
	var h := _h([T.strike(30)], T.dummy(20))
	h.play(&"strike")
	var dmg := h.events_of(CombatEvent.Kind.DAMAGED)[0]
	assert_true(dmg.flags & CombatEvent.FLAG_LETHAL != 0)
	assert_true(dmg.flags & CombatEvent.FLAG_OVERKILL != 0)
	assert_eq(dmg.value, 20, "HP の減少量は残り HP まで")
	assert_true(h.combat.is_over())
	assert_eq(h.combat.outcome, Combat.Outcome.VICTORY)


func test_multi_hit_stops_on_dead_target() -> void:
	var h := _h([T.card(&"flurry", 0, [T.dmg(5, null, 4)], {type = CardData.Type.ATTACK})], T.dummy(12))
	h.play(&"flurry")
	assert_eq(h.events_of(CombatEvent.Kind.DAMAGED).size(), 3, "3 ヒット目で倒れたら 4 ヒット目は出ない")

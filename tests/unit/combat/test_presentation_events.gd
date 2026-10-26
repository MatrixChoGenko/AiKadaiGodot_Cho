extends GutTest
## 表現層（3D の舞台、Architecture §14.6）が使うイベントの中身：敵の行動の始まりに行動 id とインテントの種類、
## ブロックで受けた 1 撃にダメージの種類が入っていること。

const T = preload("res://tests/support/builders/content_kit.gd")


func _enemy_turn_started(h: CombatHarness) -> CombatEvent:
	var list := h.events_of(CombatEvent.Kind.ENEMY_TURN_STARTED)
	return list[0] if not list.is_empty() else null


func test_enemy_turn_started_carries_attack_move() -> void:
	var h := CombatBuilder.new().with_hand([T.strike(6)]).with_enemy(Content.library.enemy(&"jawworm")).build()
	h.end_turn()
	var e := _enemy_turn_started(h)
	assert_not_null(e)
	assert_eq(e.id, &"chomp", "第 1 ターンは必ず大斧の一撃")
	assert_eq(e.snapshot.get("intent"), Intent.Kind.ATTACK)


func test_enemy_turn_started_carries_buff_move() -> void:
	var h := CombatBuilder.new().with_hand([T.strike(6)]).with_enemy(Content.library.enemy(&"cultist")).build()
	h.end_turn()
	var e := _enemy_turn_started(h)
	assert_eq(e.id, &"ritual")
	assert_eq(e.snapshot.get("intent"), Intent.Kind.BUFF)


func test_blocked_carries_damage_kind() -> void:
	var h := CombatBuilder.new().with_hand([T.strike(10)]).with_enemy(T.dummy(100)).build()
	h.enemy().block = 4
	h.play(&"strike")
	var blocked := h.events_of(CombatEvent.Kind.BLOCKED)
	assert_eq(blocked.size(), 1)
	assert_eq(blocked[0].snapshot.get("kind"), DamageEffect.Kind.ATTACK)

extends GutTest
## 3D の舞台（Architecture §14.6）：見た目の表が全部の敵を覆い、参照する素材とクリップが実在すること。
## アクターの動作の基本（踏み込み・被弾・死亡）と、3D の指示役ありで戦闘の再生が最後まで進むこと。

const UNIT_SCENE: PackedScene = preload("res://scenes/combat/unit_view.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_SAVE: String = "user://test_saves/stage_run.json"

var _saved_path: String


func before_each() -> void:
	_saved_path = SaveManager.run_path
	SaveManager.run_path = TEST_SAVE
	SaveManager.delete_run()


func after_each() -> void:
	await wait_process_frames(2)
	SaveManager.detach()
	SaveManager.delete_run()
	SaveManager.run_path = _saved_path


func _assert_spec(spec: Dictionary, label: String) -> void:
	assert_false(spec.is_empty(), "%s: 見た目の表が無い" % label)
	if spec.is_empty():
		return
	assert_true(ResourceLoader.exists(ActorCatalog.MODELS % spec["model"]), "%s: モデル" % label)
	for hand: String in ["right", "left"]:
		var weapon: String = spec.get(hand, "")
		if not weapon.is_empty():
			assert_true(ResourceLoader.exists(ActorCatalog.WEAPONS % weapon), "%s: 武器 %s" % [label, weapon])
	var clips_in_rig: Dictionary[StringName, bool] = {}
	for lib_name: String in ActorCatalog.RIG_LIBRARIES[spec["rig"]]:
		var lib := load(ActorCatalog.ANIMS % lib_name) as AnimationLibrary
		assert_not_null(lib, "%s: ライブラリ %s" % [label, lib_name])
		for clip in lib.get_animation_list():
			clips_in_rig[StringName("%s/%s" % [lib_name, clip])] = true
	var tables: Array = [spec["clips"]]
	for move: Dictionary in (spec.get("moves", {}) as Dictionary).values():
		tables.append(move)
	for table: Dictionary in tables:
		for act: StringName in table:
			var v: Variant = table[act]
			for clip: String in (v if v is Array else [v]):
				assert_true(clips_in_rig.has(StringName(clip)), "%s: %s のクリップ %s が骨格 %s に無い" % [label, act, clip, spec["rig"]])


func test_every_enemy_and_player_have_actor() -> void:
	_assert_spec(ActorCatalog.spec_for_player(), "player")
	for e in Content.library.enemies:
		_assert_spec(ActorCatalog.spec_for_enemy(e.id), String(e.id))


func test_battle_backdrops_exist() -> void:
	assert_gt(CombatScreen.BACKDROPS.size(), 0)
	for path in CombatScreen.BACKDROPS:
		var b := load(path) as BackdropData
		assert_not_null(b, "背景 %s" % path)
		if b != null:
			assert_not_null(b.texture, "背景の画像 %s" % path)


## 環境のエフェクト：背景の設定にあるものだけを表示し、値をシェーダーへ渡す。無いもの（null）はすべて非表示。
func test_battle_ambience_follows_backdrop() -> void:
	var screen := (load("res://scenes/screens/combat.tscn") as PackedScene).instantiate()
	add_child_autofree(screen)
	var amb := screen.get_node("%Ambience") as BattleAmbience
	var b := BackdropData.new()
	b.rays_enabled = true
	b.ray_angle = 42.0
	b.fireflies_front = 0.5
	amb.apply(b)
	assert_true((amb.get_node("Rays") as ColorRect).visible)
	assert_eq(((amb.get_node("Rays") as ColorRect).material as ShaderMaterial).get_shader_parameter(&"angle_deg"), 42.0)
	assert_false((amb.get_node("Mist") as ColorRect).visible, "mist_amount 0 = hidden")
	assert_false((amb.get_node("Fireflies") as ColorRect).visible)
	assert_true(amb.front.visible)
	amb.apply(null)
	assert_false((amb.get_node("Rays") as ColorRect).visible)
	assert_false(amb.front.visible)


func test_unknown_enemy_keeps_glyph() -> void:
	var stage := BattleStage.new()
	add_child_autofree(stage)
	var view := UNIT_SCENE.instantiate() as UnitView
	add_child_autofree(view)
	assert_null(stage.add_actor(1, view, ActorCatalog.spec_for_enemy(&"no_such_enemy"), -1.0))
	assert_eq(stage.actor_count(), 0)


func test_target_rings_follow_targeted_views() -> void:
	var rings := TargetRings.new()
	add_child_autofree(rings)
	var a := UNIT_SCENE.instantiate() as UnitView
	var b := UNIT_SCENE.instantiate() as UnitView
	add_child_autofree(a)
	add_child_autofree(b)
	rings.watch(a)
	rings.watch(b)
	a.set_targeted(true)
	b.set_targeted(true)
	assert_eq(rings.ring_count(), 2, "複数同時でも 1 体ずつ持つ")
	a.play_death()
	assert_eq(rings.ring_count(), 1, "倒れたらリングは消える")
	b.set_targeted(false)
	assert_eq(rings.ring_count(), 0)


func test_actor_strike_hit_and_death() -> void:
	var stage := BattleStage.new()
	stage.size = Vector2(1920, 1080)
	add_child_autofree(stage)
	var pv := UNIT_SCENE.instantiate() as UnitView
	var ev := UNIT_SCENE.instantiate() as UnitView
	add_child_autofree(pv)
	add_child_autofree(ev)
	ev.position = Vector2(1200, 0)
	var player := stage.add_actor(1, pv, ActorCatalog.spec_for_player(), 1.0)
	var enemy := stage.add_actor(2, ev, ActorCatalog.spec_for_enemy(&"jawworm"), -1.0)
	assert_eq(stage.actor_count(), 2)
	assert_gt(player.height, 1.0)
	await wait_process_frames(2)
	assert_lt(player.home.x, enemy.home.x, "プレイヤーは左、敵は右")
	var lead := player.strike(enemy)
	assert_gt(lead, 0.0, "当たる瞬間まで待つ")
	assert_lt(lead, StageActor.APPROACH + 0.3, "プレイヤーは踏み込まない（その場で振る）")
	assert_false(player.is_engaged())
	assert_gt(enemy.strike(player), StageActor.APPROACH, "敵は踏み込んでから振る")
	assert_true(enemy.is_engaged())
	player.react(false)
	assert_eq(String(player.current_clip()), "Rig_Medium_General/Hit_A")
	ev.set_targeted(true)
	assert_true(enemy.is_targeted(), "照準が付いたら輪郭線")
	enemy.react(false)
	assert_true(enemy.is_targeted(), "被弾の光と輪郭線は両立する")
	enemy.die()
	assert_true(enemy.dead)
	assert_false(enemy.is_targeted(), "倒れたら輪郭線は消える")
	assert_eq(enemy.strike(player), 0.0, "倒れたアクターは動かない")


## 舞台のエフェクトのシーンは StageEffect で、子のパーティクルはどれも 1 回きり・最初は止まっている。出すと再生され、寿命が過ぎたら消える。
func test_stage_effects_play_once_and_free() -> void:
	var stage := BattleStage.new()
	stage.size = Vector2(1920, 1080)
	add_child_autofree(stage)
	for kind: StringName in BattleStage.EFFECTS:
		var scene := BattleStage.EFFECTS[kind].instantiate()
		assert_true(scene is StageEffect, "%s: 根が StageEffect" % kind)
		var fx := scene as StageEffect
		assert_gt(fx.particles().size(), 0, "%s: パーティクルがある" % kind)
		for p in fx.particles():
			assert_true(p.one_shot and not p.emitting and p.local_coords, "%s/%s: one_shot・止まっている・local_coords" % [kind, p.name])
		fx.free()
		var spawned := stage.spawn_fx(kind, Vector3.ZERO)
		assert_true(spawned.is_playing(), "%s: 出すと再生中" % kind)
		spawned.speed = 100.0
		var ref: WeakRef = weakref(spawned)   # ラムダが解放済みのノードを捕まえるとエラーになるので WeakRef で見る
		spawned = null
		assert_true(await _until(func() -> bool: return ref.get_ref() == null, 60), "%s: 寿命が過ぎたら消える" % kind)


## 倒れたアクターは消え始めるときに vanishing を出し、舞台が死亡のエフェクトを出す。
func test_dying_actor_spawns_death_fx() -> void:
	var stage := BattleStage.new()
	stage.size = Vector2(1920, 1080)
	add_child_autofree(stage)
	var ev := UNIT_SCENE.instantiate() as UnitView
	add_child_autofree(ev)
	var enemy := stage.add_actor(2, ev, ActorCatalog.spec_for_enemy(&"jawworm"), -1.0)
	await wait_process_frames(2)
	var spawned: Array[String] = []
	stage.get_child(0).child_entered_tree.connect(func(n: Node) -> void: spawned.append(n.scene_file_path))
	watch_signals(enemy)
	enemy.speed = 20.0
	enemy.die()
	assert_true(await _until(func() -> bool: return get_signal_emit_count(enemy, "vanishing") > 0, 120), "消え始める")
	assert_has(spawned, BattleStage.EFFECTS[&"death"].resource_path)


## 戦闘のイベント → 舞台のエフェクトの対応（状態異常は増えたときだけ、表に無いステータスは出さない）。
func test_director_maps_events_to_effects() -> void:
	var stage := BattleStage.new()
	stage.size = Vector2(1920, 1080)
	add_child_autofree(stage)
	var pv := UNIT_SCENE.instantiate() as UnitView
	var ev := UNIT_SCENE.instantiate() as UnitView
	add_child_autofree(pv)
	add_child_autofree(ev)
	ev.position = Vector2(1200, 0)
	stage.add_actor(0, pv, ActorCatalog.spec_for_player(), 1.0)
	stage.add_actor(1, ev, ActorCatalog.spec_for_enemy(&"jawworm"), -1.0)
	await wait_process_frames(2)
	var director := StageDirector.new(stage, null)
	var spawned: Array[StringName] = []
	stage.get_child(0).child_entered_tree.connect(func(n: Node) -> void:
		for kind: StringName in BattleStage.EFFECTS:
			if BattleStage.EFFECTS[kind].resource_path == n.scene_file_path:
				spawned.append(kind))
	var cases: Array = [
		[_event(CombatEvent.Kind.STATUS_APPLIED, 0, 1, 2, &"poison"), [&"poison"]],
		[_event(CombatEvent.Kind.STATUS_APPLIED, -1, 1, -1, &"poison"), []],
		[_event(CombatEvent.Kind.STATUS_APPLIED, 1, 1, 2, &"strength"), [&"strength"]],
		[_event(CombatEvent.Kind.STATUS_APPLIED, 1, 0, 1, &"weak"), [&"weak"]],
		[_event(CombatEvent.Kind.STATUS_APPLIED, 0, 1, 2, &"vulnerable"), [&"vulnerable"]],
		[_event(CombatEvent.Kind.STATUS_APPLIED, 0, 0, 3, &"thorns"), []],
		[_event(CombatEvent.Kind.HEALED, 0, 0, 6), [&"heal"]],
		[_event(CombatEvent.Kind.BLOCK_CLEARED, 0, 0, 0), [&"shatter"]],
		[_event(CombatEvent.Kind.BLOCKED, 1, 0, 5, &"", {block = 2}), [&"guard"]],
		[_event(CombatEvent.Kind.BLOCKED, 1, 0, 5, &"", {block = 0}), [&"guard", &"shatter"]],
		[_event(CombatEvent.Kind.DAMAGED, -1, 1, 3, &"", {kind = DamageEffect.Kind.STATUS, hp = 10, max_hp = 40}), [&"poison_tick"]],
	]
	for c: Array in cases:
		spawned.clear()
		director.after(c[0])
		assert_eq(spawned, Array(c[1], TYPE_STRING_NAME, &"", null), str(c[0]))


func _event(kind: CombatEvent.Kind, source: int, target: int, value: int, id: StringName = &"", snapshot: Dictionary = {}) -> CombatEvent:
	var e := CombatEvent.new()
	e.kind = kind
	e.source_uid = source
	e.target_uid = target
	e.value = value
	e.id = id
	e.snapshot = snapshot
	return e


func test_combat_replays_with_director() -> void:
	var main := MAIN_SCENE.instantiate()
	(main.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
	add_child_autofree(main)
	main.call(&"start_new_run", 7)
	var run := main.get(&"run") as RunController
	var id := RunFixtures.force_next(run, MapNode.Type.BATTLE, &"jawworm")
	assert_true((main.call(&"current_screen") as MapScreen).choose_node(id))
	var screen := main.call(&"current_screen") as CombatScreen
	assert_not_null(screen.presenter.director)
	assert_eq(screen.stage.actor_count(), 2)
	screen.presenter.fast_forward = true
	assert_true(await _until(screen.can_act, 3000), "開戦の再生が終わる")
	var enemy := screen.ctl.combat.enemies[0]
	var card: Card = null
	for c in screen.ctl.combat.piles.hand:
		if screen.ctl.needs_target(c):
			card = c
			break
	assert_not_null(card)
	var hp := enemy.hp
	var spawned: Array[String] = []
	screen.stage.get_child(0).child_entered_tree.connect(func(n: Node) -> void: spawned.append(n.scene_file_path))
	assert_true(screen.try_play(card, enemy))
	screen.presenter.fast_forward = true
	assert_true(await _until(screen.can_act, 3000), "攻撃の再生が終わる")
	assert_lt(screen.unit_view(enemy.uid).shown_hp, hp)
	assert_has(spawned, BattleStage.EFFECTS[&"hit"].resource_path, "当たる瞬間に打撃のエフェクト")
	screen.end_turn()
	screen.presenter.fast_forward = true
	assert_true(await _until(screen.can_act, 3000), "敵のターンの再生が終わる")


## 再生中でも次のカードを出せる（テンポを止めない）。残りの演出は片付けられ、最後に表示がモデルと一致する。
func test_cards_can_be_played_back_to_back_during_replay() -> void:
	var main := MAIN_SCENE.instantiate()
	(main.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
	add_child_autofree(main)
	main.call(&"start_new_run", 7)
	var run := main.get(&"run") as RunController
	var id := RunFixtures.force_next(run, MapNode.Type.BATTLE, &"jawworm")
	assert_true((main.call(&"current_screen") as MapScreen).choose_node(id))
	var screen := main.call(&"current_screen") as CombatScreen
	assert_false(screen.can_play(), "開戦の再生でプレイヤーのターンを見せるまでは出せない")
	assert_true(await _until(screen.can_play, 3000))
	var enemy := screen.ctl.combat.enemies[0]
	var attacks: Array[Card] = []
	for c in screen.ctl.combat.piles.hand:
		if screen.ctl.needs_target(c) and screen.ctl.cost_of(c) == 1:
			attacks.append(c)
	assert_gte(attacks.size(), 2, "手札にコスト 1 のアタックが 2 枚以上ある（シード 7）")
	if attacks.size() < 2:
		return
	assert_true(screen.try_play(attacks[0], enemy))
	await get_tree().process_frame
	assert_false(screen.presenter.is_idle(), "1 枚目の演出の途中")
	assert_true(screen.can_play(), "演出の途中でも次のカードを出せる")
	assert_false(screen.can_act(), "ターン終了は再生を待つ")
	assert_true(screen.try_play(attacks[1], enemy))
	screen.presenter.fast_forward = true
	assert_true(await _until(screen.can_act, 3000), "再生が終わる")
	assert_eq(screen.unit_view(enemy.uid).shown_hp, enemy.hp, "表示がモデルに追いつく")


func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

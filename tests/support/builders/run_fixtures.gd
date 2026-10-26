class_name RunFixtures extends RefCounted
## テスト支援：ラン進行のテスト用のコンテンツと RunController。
## 正式コンテンツはアクト 1 つだけなので、アクト移行と最終勝利の経路を通すために、正式コンテンツを複製して
## アクトを増やしたライブラリを作る（付録 C の M3 決定：複数アクトはテスト用だけ）。正式の Resource は書き換えない。


## 正式コンテンツを元に、アクトを count 個にしたライブラリ。エンカウント / イベントは全アクトに出るよう複製する。
static func multi_act_library(base: ContentLibrary, count: int = 3) -> ContentLibrary:
	var lib := ContentLibrary.new()
	lib.cards = base.cards
	lib.statuses = base.statuses
	lib.keywords = base.keywords
	lib.relics = base.relics
	lib.potions = base.potions
	lib.enemies = base.enemies
	lib.config = base.config
	var all_acts := (1 << count) - 1
	var bosses: Array[EncounterData] = []
	for e in base.encounters:
		var copy := e.duplicate() as EncounterData
		copy.acts = all_acts
		lib.encounters.append(copy)
		if copy.rank == EnemyData.Rank.BOSS:
			bosses.append(copy)
	for e in base.events:
		var copy := e.duplicate() as EventData
		copy.acts = all_acts
		lib.events.append(copy)
	var template: ActData = RunController.acts_of(base)[0]
	for i in count:
		var act := template.duplicate() as ActData
		act.id = StringName("test_act_%d" % (i + 1))
		act.number = i + 1
		act.bosses = bosses
		lib.acts.append(act)
	return lib


## HP を大きくした RunConfig（ランダムなボットでも後半のアクトまで届くようにする）。正式の config は書き換えない。
static func tough_config(base: RunConfig, max_hp: int = 2500) -> RunConfig:
	var cfg := base.duplicate() as RunConfig
	cfg.start_max_hp = max_hp
	return cfg


## 小さなマップ（行数を減らす）のアクトにしたライブラリ。フローのテストを速くする。
static func short_library(base: ContentLibrary, acts: int = 1, rows: int = 7) -> ContentLibrary:
	var lib := multi_act_library(base, acts)
	for a in lib.acts:
		a.rows = rows
	return lib


static func new_run(lib: ContentLibrary, seed_value: int = 1, cfg: RunConfig = null) -> RunController:
	var run := RunController.new(lib, cfg)
	run.start_new(seed_value)
	return run


## 次に選べるノードの 1 つ目を指定の種類と内容に書き換え、その id を返す（フローのテスト用）。
static func force_next(run: RunController, type: MapNode.Type, content_id: StringName = &"") -> int:
	var node := run.choices()[0]
	node.type = type
	node.encounter = &""
	node.event = &""
	match type:
		MapNode.Type.EVENT:
			node.event = content_id
		MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.BOSS:
			node.encounter = content_id
	return node.id


## 戦闘を勝利で終わらせる（燃える血などの戦闘終了の Hook は通常どおり働く）。
static func win_combat(run: RunController) -> void:
	for e in run.combat.combat.alive_enemies():
		e.hp = 0
		run.combat.combat.finalize_death(e)


static func lose_combat(run: RunController) -> void:
	var p := run.combat.combat.player
	p.hp = 0
	run.combat.combat.finalize_death(p)


## JSON を通してセーブ → ロードした RunState。
static func reload_state(state: RunState, lib: ContentLibrary) -> RunState:
	var text := JSON.stringify(RunSerializer.to_dict(state))
	var s := RunSerializer.new()
	var loaded := s.from_dict(JSON.parse_string(text) as Dictionary, lib)
	assert(loaded != null, "reload failed: %s" % s.error)
	return loaded


static func dump(state: RunState) -> String:
	return JSON.stringify(RunSerializer.to_dict(state))

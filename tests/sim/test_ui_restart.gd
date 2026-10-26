extends GutTest
## M5 受け入れ：ゲームを閉じて再起動すると、どのチェックポイントからも正しく再開できる（F24、GameDesign §14.2）。
## 1 本目の Main で UiBot がランを最後まで遊び、チェックポイントでセーブされたファイルの中身をすべて記録する。
## 記録したファイルごとに、新しい Main（再起動の代わり。セーブファイル以外は何も引き継がない）を作って「続きから」を押し、
##   - 1 本目がそのチェックポイントの直後に見せていた画面と同じ画面になる
##   - ランの状態（セーブ形式の辞書）が、1 本目のチェックポイントの直後と一致する（同じ乱数状態で同じ内容を作り直す）
## を確かめる。4 種類のチェックポイントそれぞれ 1 つは、再開したランを UiBot で最後まで遊んでエラーが無いことも確かめる。
## HP を大きくして（tough_config）ボスまで届かせ、ショップ・イベント・休憩・宝箱も通るようにする。
## ラン数は環境変数 TRYCARD_RESTART_RUNS（既定 2）。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_SAVE: String = "user://test_saves/ui_restart.json"
const REASONS: Array[StringName] = [RunController.CP_NODE_ENTERED, RunController.CP_COMBAT_STARTED,
		RunController.CP_REWARD_GENERATED, RunController.CP_RETURNED_TO_MAP]

var _saved_path: String
## 1 本目の記録：{reason, step, text（セーブファイル）, screen（直後の画面のスクリプト）, state（直後の状態の辞書）}。
var _records: Array[Dictionary] = []
var _step: int = 0
var _config: RunConfig


func before_all() -> void:
	_saved_path = SaveManager.run_path
	SaveManager.run_path = TEST_SAVE
	_config = RunFixtures.tough_config(Content.library.config)


func after_all() -> void:
	SaveManager.detach()
	SaveManager.delete_run()
	SaveManager.run_path = _saved_path


func _runs() -> int:
	var env := OS.get_environment("TRYCARD_RESTART_RUNS")
	return env.to_int() if env.is_valid_int() else 2


func _spawn() -> Node:
	var main := MAIN_SCENE.instantiate()
	(main.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
	main.set(&"config_override", _config)
	add_child(main)
	return main


func _free(main: Node) -> void:
	SaveManager.detach()
	remove_child(main)
	main.queue_free()
	await wait_process_frames(2)


func _state_dict(main: Node) -> Dictionary:
	return RunSerializer.to_dict((main.get(&"run") as RunController).state)


## 1 本目：遊びながらチェックポイントごとにセーブファイルを記録する。直後の画面と状態は次のステップの頭で埋める。
func _record_run(seed_value: int) -> void:
	_records.clear()
	SaveManager.delete_run()
	var main := _spawn()
	main.call(&"start_new_run", seed_value)
	var run := main.get(&"run") as RunController
	run.checkpoint_reached.connect(_on_checkpoint)   # SaveManager の後につなぐので、ファイルは書き終わっている
	_records.append({reason = RunController.CP_RETURNED_TO_MAP, step = 0, text = FileAccess.get_file_as_string(TEST_SAVE)})
	var bot := UiBot.new(main, seed_value)
	var alive := true
	_step = 0
	while alive and _step < 60000:
		_fill_after(main)
		_step += 1
		alive = bot.step()
		await get_tree().process_frame
	assert_true(bot.failure.is_empty(), "seed %d: %s" % [seed_value, bot.failure])
	run.checkpoint_reached.disconnect(_on_checkpoint)
	await _free(main)


func _on_checkpoint(reason: StringName) -> void:
	_records.append({reason = reason, step = _step, text = FileAccess.get_file_as_string(TEST_SAVE)})


## 直前のステップで記録したチェックポイントに、そのステップが終わった後の画面と状態を付ける。
## 同じステップで 2 回以上セーブしたときは最後の 1 つだけに付ける（前のものは画面の確認だけ外す）。
func _fill_after(main: Node) -> void:
	var last := -1
	for i in _records.size():
		if not _records[i].has(&"screen") and _records[i][&"step"] == _step:
			last = i
	if last < 0 or main.get(&"run") == null:
		return
	_records[last][&"screen"] = (main.call(&"current_screen") as Screen).get_script()
	_records[last][&"state"] = _state_dict(main)


## 2 本目：記録したセーブファイルから新しい Main で再開する。
func _restart_from(rec: Dictionary, play_to_end: bool) -> void:
	SaveManager.delete_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE.get_base_dir()))
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(rec[&"text"])
	f.close()
	var main := _spawn()
	var menu := main.call(&"current_screen") as MainMenuScreen
	var cont := menu.get_node("%ContinueButton") as Button
	assert_true(cont.visible and not cont.disabled, "%s: the save is readable" % rec[&"reason"])
	cont.pressed.emit()
	var label := "%s @ step %d" % [rec[&"reason"], rec[&"step"]]
	if rec.has(&"screen"):
		assert_eq((main.call(&"current_screen") as Screen).get_script(), rec[&"screen"], "%s: same screen" % label)
		var resumed := _state_dict(main)
		assert_eq(JSON.stringify(resumed), JSON.stringify(rec[&"state"]), "%s: same state as without the restart" % label)
	if play_to_end:
		var bot := UiBot.new(main, 77)
		var finished: bool = await bot.play(get_tree())
		assert_true(finished, "%s: resumed run reaches the end: %s" % [label, bot.failure])
		assert_is(main.call(&"current_screen"), MainMenuScreen)
	await _free(main)


func test_restart_from_every_checkpoint() -> void:
	var seen: Dictionary[StringName, int] = {}
	var total := 0
	for r in _runs():
		await _record_run(3000 + r)
		var played: Dictionary[StringName, bool] = {}
		for rec in _records:
			var reason: StringName = rec[&"reason"]
			seen[reason] = seen.get(reason, 0) + 1
			var play := not played.has(reason) and r == 0
			played[reason] = true
			await _restart_from(rec, play)
			total += 1
	gut.p("restarted from %d checkpoints: %s" % [total, seen])
	for reason in REASONS:
		assert_gt(seen.get(reason, 0), 0, "covered %s" % reason)

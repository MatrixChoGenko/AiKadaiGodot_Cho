extends GutTest
## M4 受け入れ：メインメニューから画面を操作して 1 ランを最後まで（勝利または敗北）遊び、メインメニューに戻るまでエラーが出ない。
## UiBot が画面の公開メソッド（クリックと同じ経路）を呼ぶ。GUT は push_error とエンジンのエラーを失敗として扱う。
## ラン数は環境変数 TRYCARD_UI_RUNS（既定 3）。うち 1 本は HP を大きくしてボスまで届かせる。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_SAVE: String = "user://test_saves/ui_run.json"

var _saved_path: String


func before_all() -> void:
	_saved_path = SaveManager.run_path
	SaveManager.run_path = TEST_SAVE


func after_all() -> void:
	SaveManager.detach()
	SaveManager.delete_run()
	SaveManager.run_path = _saved_path


func _runs() -> int:
	var env := OS.get_environment("TRYCARD_UI_RUNS")
	return env.to_int() if env.is_valid_int() else 3


func _play(seed_value: int, cfg: RunConfig) -> UiBot:
	SaveManager.delete_run()
	var main := MAIN_SCENE.instantiate()
	(main.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
	main.set(&"config_override", cfg)
	add_child_autofree(main)
	main.call(&"start_new_run", seed_value)
	var bot := UiBot.new(main, seed_value)
	var finished: bool = await bot.play(get_tree())
	assert_true(finished, "seed %d: %s" % [seed_value, bot.failure])
	assert_is(main.call(&"current_screen"), MainMenuScreen, "back on the main menu")
	assert_false(SaveManager.has_run(), "save deleted at the end of the run")
	gut.p("seed %d: %s" % [seed_value, bot.stats])
	main.queue_free()
	await wait_process_frames(2)
	return bot


func test_ui_runs_reach_the_end() -> void:
	var outcomes: Array[String] = []
	for i in _runs():
		var cfg: RunConfig = RunFixtures.tough_config(Content.library.config) if i == 0 else null
		var bot := await _play(1000 + i, cfg)
		outcomes.append(bot.stats.outcome)
		assert_gt(bot.stats.combats, 0)
	assert_true(outcomes.has("victory"), "the tough run reaches the boss and wins: %s" % [outcomes])

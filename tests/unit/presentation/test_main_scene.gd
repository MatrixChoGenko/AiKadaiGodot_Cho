extends GutTest
## Main シーン：メインメニュー（続きから / 新しいランの 2 回押し / 放棄）、フェーズ → 画面の切り替え、セーブの接続（M4）。
## セーブは user://test_saves/ に差し替え、本物のセーブには触らない。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const MAIN_SCRIPT = preload("res://src/presentation/main/main.gd")
const TEST_SAVE: String = "user://test_saves/main_scene_run.json"

var _main: Node
var _host: ScreenHost
var _modals: ModalHost
var _saved_path: String


func before_each() -> void:
	_saved_path = SaveManager.run_path
	SaveManager.run_path = TEST_SAVE
	SaveManager.delete_run()
	_spawn_main()


func after_each() -> void:
	await wait_process_frames(2)   # queue_free した画面とパネルの子を解放させる（GUT の Orphans 検出）
	SaveManager.detach()
	SaveManager.delete_run()
	SaveManager.run_path = _saved_path


func _spawn_main() -> void:
	_main = MAIN_SCENE.instantiate()
	# _ready より前にフェードを切り、切り替えを即時にする。
	(_main.get_node("Screens/ScreenHost") as ScreenHost).fade_seconds = 0.0
	add_child_autofree(_main)
	_host = _main.get_node("%ScreenHost") as ScreenHost
	_modals = _main.get_node("%ModalHost") as ModalHost


func _menu() -> MainMenuScreen:
	return _host.current as MainMenuScreen


func _press(screen: Node, unique: String) -> void:
	(screen.get_node("%" + unique) as Button).pressed.emit()


func test_starts_on_main_menu_without_top_bar() -> void:
	assert_is(_host.current, MainMenuScreen)
	assert_false((_main.get_node("%TopBarView") as Control).visible)
	assert_false((_menu().get_node("%ContinueButton") as Button).visible, "no save -> no continue")
	assert_false((_menu().get_node("%AbandonButton") as Button).visible)


func test_new_run_shows_map_and_saves() -> void:
	_press(_menu(), "NewRunButton")
	assert_is(_host.current, MapScreen)
	assert_true((_main.get_node("%TopBarView") as Control).visible)
	assert_true(SaveManager.has_run(), "returned_to_map checkpoint wrote a save")


## 図鑑：メニューから開いて「戻る」でメニューへ。ランは始まらず、セーブも作らない。
func test_compendium_opens_from_menu_and_returns() -> void:
	_press(_menu(), "CompendiumButton")
	assert_is(_host.current, CompendiumScreen)
	assert_false((_main.get_node("%TopBarView") as Control).visible)
	assert_false(SaveManager.has_run())
	(_host.current as CompendiumScreen).back()
	assert_is(_host.current, MainMenuScreen)


func test_every_phase_has_a_screen() -> void:
	var screens: Dictionary = _main.get(&"screens")
	for phase: int in RunPhase.Id.values():
		assert_true(screens.has(phase), "no screen for %s" % RunPhase.Id.keys()[phase])
		assert_not_null(screens.get(phase), "null screen for %s" % RunPhase.Id.keys()[phase])


## デバッグ：「全カードで開始」で初期デッキが全カード 1 枚ずつ（強化版は除き、状態異常・呪いは含む）になる。
func test_debug_all_cards_deck() -> void:
	var menu := _menu()
	(menu.get_node("%AllCardsCheck") as CheckBox).button_pressed = true
	_press(menu, "NewRunButton")
	assert_is(_host.current, MapScreen)
	var run: RunController = _main.get(&"run")
	var expected: Array[CardData] = MAIN_SCRIPT.all_cards_config(Content.library, Content.library.config).starting_deck
	assert_eq(run.state.deck.size(), expected.size())
	var types := {}
	for c in run.state.deck.cards:
		types[c.data.type] = true
		assert_false(c.data.name.ends_with("+"), "no upgraded card: %s" % c.data.name)
	for t: int in CardData.Type.values():
		assert_true(types.has(t), "has type %s" % CardData.Type.keys()[t])
	assert_eq(Content.library.config.starting_deck.size(), 10, "the shared RunConfig is untouched")


func test_new_run_needs_second_press_when_save_exists() -> void:
	_main.call(&"start_new_run", 7)
	_main.call(&"show_main_menu")
	var menu := _menu()
	assert_true((menu.get_node("%ContinueButton") as Button).visible)
	_press(menu, "NewRunButton")
	assert_is(_host.current, MainMenuScreen, "first press only asks for confirmation")
	assert_string_contains((menu.get_node("%NewRunButton") as Button).text, "もう一度")
	_press(menu, "NewRunButton")
	assert_is(_host.current, MapScreen)


func test_abandon_deletes_save_after_second_press() -> void:
	_main.call(&"start_new_run", 7)
	_main.call(&"show_main_menu")
	var menu := _menu()
	_press(menu, "AbandonButton")
	assert_true(SaveManager.has_run(), "first press only asks for confirmation")
	_press(menu, "AbandonButton")
	assert_false(SaveManager.has_run())
	assert_false((menu.get_node("%ContinueButton") as Button).visible)


func test_continue_resumes_saved_run() -> void:
	_main.call(&"start_new_run", 4242)
	var run := _main.get(&"run") as RunController
	var first := run.choices()[0].id
	_main.call(&"show_main_menu")
	_press(_menu(), "ContinueButton")
	assert_is(_host.current, MapScreen)
	var resumed := _main.get(&"run") as RunController
	assert_eq(resumed.state.seed_value, 4242)
	assert_eq(resumed.choices()[0].id, first)


func test_unreadable_save_disables_continue() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE.get_base_dir()))
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	_menu().refresh_save()
	var b := _menu().get_node("%ContinueButton") as Button
	assert_true(b.visible)
	assert_true(b.disabled)
	assert_eq(b.text, "セーブを読み込めません")


func test_switch_clears_modals() -> void:
	_main.call(&"start_new_run", 3)
	_main.call(&"_on_top_bar_deck_pressed")
	assert_false(_modals.is_empty(), "deck viewer opened")
	var run := _main.get(&"run") as RunController
	(_host.current as MapScreen).choose_node(run.choices()[0].id)
	assert_true(_modals.is_empty())


## フェードありでも旧画面が解放される（旧画面を止めた後、その画面の Tween でフェードすると止まったまま残っていた）。
func test_old_screen_freed_after_fade() -> void:
	_host.fade_seconds = 0.05
	_main.call(&"start_new_run", 3)
	_main.call(&"show_main_menu")
	await wait_seconds(0.3)
	assert_eq(_host.get_child_count(), 1)


func test_only_one_screen_alive_after_switch() -> void:
	_main.call(&"start_new_run", 3)
	_main.call(&"show_main_menu")
	await wait_process_frames(2)   # queue_free の反映を待つ
	assert_eq(_host.get_child_count(), 1)

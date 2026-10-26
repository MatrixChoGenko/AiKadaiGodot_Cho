extends Node
## ⑤ Presentation：常駐するメインシーン（Autoload ではない）。RunController を保持し、phase に応じて画面を切り替える（Architecture §13.1）。
## - メインメニューは Run の外側にあり、ここが直接管理する。
## - ランを始める / 再開するときに SaveManager.attach(run) し、チェックポイントでオートセーブさせる（ルール 10）。
## - 画面の遷移は run.phase_changed だけをきっかけにする（画面は run のコマンドを呼ぶだけ。ルール 8）。
## - 協力プレイ（GameDesign §21）：メニュー → ロビー（LobbyScreen）→ Net.run_starting でランを作る。全員の PC が同じ
##   RunController を持ち、Net が配るコマンドで進める。セーブはホストだけ（協力プレイ用のファイル）。切断・ずれは案内を出してメニューへ。

const LOBBY_SCENE: PackedScene = preload("res://scenes/screens/lobby.tscn")

## ライセンスが不明なので Git には入れていない（.gitignore）。無い PC では OS の標準カーソルのまま。
const CURSOR_PATH := "res://assets/textures/ui/cursor_stone_green.png"

## フェーズ → 画面の対応表。画面を追加してもコードは変えない（Architecture §13.1）。
@export var screens: Dictionary[RunPhase.Id, PackedScene] = {}
@export var main_menu_scene: PackedScene
@export var compendium_scene: PackedScene

var run: RunController
## テスト用：RunConfig を差し替える（null = コンテンツの既定）。
var config_override: RunConfig
## テスト用：コンテンツを差し替える（null = Content.library。複数アクトの構成でアクト移行を通すため）。
var content_override: ContentLibrary

@onready var _screen_host: ScreenHost = %ScreenHost
@onready var _modal_host: ModalHost = %ModalHost
@onready var _top_bar: TopBar = %TopBarView


func _ready() -> void:
	if ResourceLoader.exists(CURSOR_PATH):
		Input.set_custom_mouse_cursor(load(CURSOR_PATH))
	_top_bar.deck_pressed.connect(_on_top_bar_deck_pressed)
	_top_bar.potion_discard_requested.connect(_on_top_bar_potion_discard_requested)
	Net.run_starting.connect(_on_net_run_starting)
	Net.session_ended.connect(_on_net_session_ended)
	Net.desync_detected.connect(_on_net_desync)
	Net.command_applied.connect(_on_net_command_applied)
	show_main_menu()


## プロジェクト設定でカーソルを指定すると、終了時に画像が解放されずにエラーが出る。コードで付けて外す。
func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)


func show_main_menu() -> void:
	_end_run()
	if Net.is_active():
		Net.leave()
	var menu := _switch_to(main_menu_scene, {}) as MainMenuScreen
	menu.continue_requested.connect(continue_run)
	menu.new_run_requested.connect(start_new_run)
	menu.compendium_requested.connect(show_compendium)
	menu.coop_requested.connect(show_lobby)
	menu.quit_requested.connect(_on_main_menu_quit_requested)


## 協力プレイのロビー。message は切断の理由などの案内。
func show_lobby(message: String = "") -> void:
	_end_run()
	var screen := _switch_to(LOBBY_SCENE, {modals = _modal_host, message = message}) as LobbyScreen
	screen.back_requested.connect(show_main_menu)


## 図鑑（ランの外の画面）。「戻る」でメインメニューへ。
func show_compendium() -> void:
	var screen := _switch_to(compendium_scene, {modals = _modal_host}) as CompendiumScreen
	screen.back_requested.connect(show_main_menu)


## 新しいランを始める（前のランのセーブは消える）。
## debug_all_cards：デバッグ用。初期デッキを全カードにする（メインメニューのチェック。デバッグビルドのみ）。
func start_new_run(seed_value: int, debug_all_cards: bool = false) -> void:
	SaveManager.delete_run()
	_begin_run()
	if debug_all_cards:
		run.config = all_cards_config(run.content, run.config)
	Log.info(&"run", "new run (seed %d%s)" % [seed_value, ", all cards" if debug_all_cards else ""])
	run.start_new(seed_value)


## デバッグ用：初期デッキを全カード 1 枚ずつ（基本のカード・状態異常・呪い。強化版は除く）にした RunConfig。
## カードの見た目をまとめて確かめるため。上部バーの「デッキ」で一覧できる。
static func all_cards_config(lib: ContentLibrary, base: RunConfig) -> RunConfig:
	var cfg := base.duplicate() as RunConfig
	cfg.starting_deck = lib.base_cards()
	return cfg


## ロードした状態から再開する。
func continue_run(state: RunState) -> void:
	_begin_run()
	Log.info(&"run", "continue run (seed %d, phase %s)" % [state.seed_value, RunPhase.Id.keys()[state.phase]])
	run.resume(state)


func show_phase(phase: RunPhase.Id) -> Screen:
	var scene: PackedScene = screens.get(phase)
	assert(scene != null, "main.tscn: no screen for phase %s" % RunPhase.Id.keys()[phase])
	# 戦闘 → 報酬：戦闘画面を破棄せず、暗くした戦場として報酬の後ろに残す（StS2 と同じ）
	var keep := phase == RunPhase.Id.REWARD and current_screen() is CombatScreen
	var screen := _switch_to(scene, {run = run, modals = _modal_host, top_bar = _top_bar, phase = phase, battle_behind = keep}, keep)
	screen.run_changed.connect(_refresh_top_bar)
	screen.main_menu_requested.connect(show_main_menu)
	_refresh_top_bar()
	return screen


func current_screen() -> Screen:
	return _screen_host.current


## coop = 協力プレイ：セーブはホストだけが協力プレイ用のファイルに書く（参加者は書かない）。
func _begin_run(coop: bool = false) -> void:
	_end_run()
	run = RunController.new(content_override if content_override != null else Content.library, config_override)
	if not coop:
		Net.last_seat = 0
		SaveManager.attach(run)
	elif Net.is_host():
		SaveManager.use_coop_path(true)
		SaveManager.attach(run)
	run.phase_changed.connect(_on_run_phase_changed)


func _end_run() -> void:
	if run == null:
		return
	SaveManager.detach()
	SaveManager.use_coop_path(false)
	run.phase_changed.disconnect(_on_run_phase_changed)
	if Net.run == run:
		Net.run = null
	run = null


# —— 協力プレイ ——

func _on_net_run_starting(info: Dictionary) -> void:
	_begin_run(true)
	Net.run = run
	var names := PackedStringArray(info.get("names", []))
	if String(info.get("mode", "")) == "resume":
		var serializer := RunSerializer.new()
		var state := serializer.from_dict(info.get("save", {}) as Dictionary, run.content)
		if state == null or state.players.size() != names.size():
			Log.warn(&"net", "cannot resume coop save: %s" % serializer.error)
			Net.leave()
			show_lobby("協力プレイのセーブを読み込めませんでした（%s）" % serializer.error)
			return
		Log.info(&"run", "coop resume (%d players, seat %d)" % [names.size(), Net.seat])
		run.resume(state)
		return
	if Net.is_host():
		SaveManager.delete_run()
	var seed_value := String(info.get("seed", "0")).to_int()
	Log.info(&"run", "coop run (seed %d, %d players, seat %d)" % [seed_value, names.size(), Net.seat])
	run.start_new(seed_value, true, names)


func _on_net_session_ended(reason: String) -> void:
	if run != null and run.is_coop() and not run.is_over():
		show_lobby(reason)


func _on_net_desync(seq: int) -> void:
	if run == null or not run.is_coop():
		return
	var dialog := AcceptDialog.new()
	dialog.title = "同期のずれ"
	dialog.dialog_text = "ほかの PC と状態がずれました（コマンド %d）。\nいったんメニューに戻り、ホストの「続きから」で再開してください。" % seq
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


## ほかの人の操作（投票・進む・Ready）も含めて、全員に共通の表示を更新する。
func _on_net_command_applied(_cmd: Dictionary) -> void:
	if run == null:
		return
	_refresh_top_bar()
	var screen := current_screen()
	if screen is MapScreen:
		(screen as MapScreen).show_votes()
	elif screen is CombatScreen:
		(screen as CombatScreen).refresh_party()


func _switch_to(scene: PackedScene, args: Dictionary, keep_backdrop: bool = false) -> Screen:
	_modal_host.clear()
	TimeFx.reset()
	Fx.clear()
	var screen := _screen_host.show_screen(scene, args, keep_backdrop)
	_top_bar.visible = screen.show_top_bar
	return screen


func _refresh_top_bar() -> void:
	if run != null and run.state != null and _top_bar.visible:
		_top_bar.show_run(run)


func _on_run_phase_changed(phase: RunPhase.Id) -> void:
	show_phase(phase)


func _on_top_bar_deck_pressed() -> void:
	if run == null or not _modal_host.is_empty():
		return
	var deck := Party.me(run).deck
	_modal_host.push(preload("res://scenes/widgets/card_list_modal.tscn"), {
		title = "デッキ（%d 枚）" % deck.size(),
		entries = CardListModal.entries_of_cards(deck.cards),
	})


func _on_top_bar_potion_discard_requested(slot: int) -> void:
	if run != null:
		Party.act(run, CoopCommands.DISCARD_POTION, {slot = slot}, _on_potion_discarded)


func _on_potion_discarded(ok: bool) -> void:
	if ok:
		_refresh_top_bar()


func _on_main_menu_quit_requested() -> void:
	get_tree().quit()

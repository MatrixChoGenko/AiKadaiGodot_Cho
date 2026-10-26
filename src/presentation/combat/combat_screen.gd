class_name CombatScreen extends Screen
## ⑤ Presentation：戦闘画面（GameDesign §15.4 / Architecture §14、U04〜U07）。組み立てと配線を担う。
## - イベントの再生は CombatPresenter、手札の入力は HandInput、表示は各 View。
## - 書き込みは CombatController のコマンドだけ。再生中・敵のターン・カード選択中・戦闘終了は入力をロックする（can_act）。
## - 再生が終わるたびにモデルと突き合わせ（sync_from_model）、カード選択が待っていればパネルを開き、戦闘が終わっていれば結果を出す。
## enter(args)：run（ラン中）または combat（CombatController。sandbox 用）。run が無いときの「続ける」は sandbox_continue を出す。
## ポーションはトップバーの枠を借りて操作する（StS2 と同じく戦闘中もバーに出す）。トップバーが無いとき（sandbox）は自前の枠。
## 協力プレイ（GameDesign §21）：手札・山・エネルギー・ポーションは自分の席（Party.seat）のもの。味方は自分の後ろに並べ、
## 頭上に名前と Ready の印を出す。操作は Party 経由でホストへ送り、ターン終了は Ready（もう一度押すと取り消し）。

signal sandbox_continue

const UNIT_SCENE: PackedScene = preload("res://scenes/combat/unit_view.tscn")
## 協力プレイの味方の立ち位置：自分（PlayerView）から 1 人ごとに左上（奥）へずらす量（px）。
## 上へのずれは、一番左の味方の HP バーがエネルギーのオーブ（左下）に重ならない量にしてある（4 人で確認）。
const ALLY_STEP: Vector2 = Vector2(-150, -44)
const TOAST_SECONDS: float = 1.2
## ターン終了ボタンが隠れるときに下がる量（px）と、敵のターンのエネルギーのオーブの色。
const END_TURN_DROP: float = 140.0
const ENERGY_DIM: Color = Color(0.45, 0.42, 0.45)
## 勝利してから自動で報酬へ進むまでの秒数（勝利の紙吹雪を見せる間）。
const VICTORY_HOLD: float = 1.1
## 報酬の背景になったとき、操作用の表示（手札・山・エネルギー・ボタン）が消える秒数。
const BACKDROP_FADE: float = 0.25
## 戦闘の背景（BackdropData。画像と、光の筋・霧・ホタルの設定）の候補。戦闘ごとにどれか 1 つ（使う 1 つだけ読み込む）。
const BACKDROPS: Array[String] = [
	"res://assets/textures/backgrounds/battle_forest_ruins_1.tres",
	"res://assets/textures/backgrounds/battle_forest_ruins_2.tres",
	"res://assets/textures/backgrounds/battle_forest_ruins_3.tres",
]

var ctl: CombatController
## 自分の席の番号（1 人プレイ・サンドボックスでは 0）。
var my_index: int = 0

var _units: Dictionary[int, UnitView] = {}
var _last_version: int = -1
var _last_aim: Combatant
var _choice_open: bool = false
var _toast_tween: Tween
var _end_turn_tween: Tween
## ターン終了ボタンの定位置（シーンの offset_top）。position.y を動かすと offset_top も書き換わるので、最初に覚えておく。
var _end_turn_home_offset: float = 0.0
var _energy_tween: Tween
var _auto_continue: bool = false
## 協力プレイ：ホストの返事を待っている（二重に送らない）。
var _sending: bool = false
var _turn_no: int = 1
## 協力プレイ：味方の名前と Ready の印（uid → Label）。
var _ally_tags: Dictionary[int, Label] = {}

@onready var hand: HandView = %Hand
@onready var arrow: TargetArrow = %Arrow
@onready var presenter: CombatPresenter = %Presenter
@onready var hand_input: HandInput = %Input
@onready var stage: BattleStage = %Stage
@onready var rings: TargetRings = %Rings
@onready var _backdrop: TextureRect = %Backdrop
@onready var _ambience: BattleAmbience = %Ambience
@onready var _player_view: UnitView = %PlayerView
@onready var _enemy_row: HBoxContainer = %EnemyRow
@onready var _banner: TurnBanner = %Banner
@onready var _own_potions: PotionBar = %Potions
var _potions: PotionBar
@onready var _energy: GlyphBadge = %EnergyOrb
@onready var _energy_art: TextureRect = %EnergyOrbArt
@onready var _draw_button: PileButton = %DrawButton
@onready var _discard_button: PileButton = %DiscardButton
@onready var _exhaust_button: PileButton = %ExhaustButton
@onready var _end_turn: Button = %EndTurnButton
@onready var _toast: Label = %Toast
@onready var _result_panel: Control = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_info: Label = %ResultInfo
@onready var _continue: Button = %ContinueButton


func enter(args: Dictionary) -> void:
	super.enter(args)
	ctl = args.get(&"combat") as CombatController
	if ctl == null and run != null:
		ctl = run.combat
	assert(ctl != null, "CombatScreen: no combat")
	var c := ctl.combat
	my_index = Party.seat() if run != null else 0
	var backdrop := load(BACKDROPS[backdrop_index()]) as BackdropData
	_backdrop.texture = backdrop.texture
	_ambience.apply(backdrop)
	var me := my_unit()
	_player_view.setup(me)
	_units[me.uid] = _player_view
	stage.add_actor(me.uid, _player_view, ActorCatalog.spec_for_player(), 1.0)
	_add_allies()
	for e in c.enemies:
		var v := UNIT_SCENE.instantiate() as UnitView
		_enemy_row.add_child(v)
		v.setup(e)
		_units[e.uid] = v
		stage.add_actor(e.uid, v, ActorCatalog.spec_for_enemy(e.data.id), -1.0)
		rings.watch(v)
	presenter.director = StageDirector.new(stage, self)
	_end_turn.visible = false
	set_energy(0, 0)
	_potions = top_bar.lend_potions(_potion_actions, _on_potion_action_chosen) if top_bar != null else null
	_own_potions.visible = _potions == null
	if _potions == null:
		_potions = _own_potions
		_potions.actions_provider = _potion_actions
		_potions.action_chosen.connect(_on_potion_action_chosen)
	show_potions()
	_draw_button.pressed.connect(_open_pile.bind(Pile.Id.DRAW))
	_discard_button.pressed.connect(_open_pile.bind(Pile.Id.DISCARD))
	_exhaust_button.pressed.connect(_open_pile.bind(Pile.Id.EXHAUST))
	_end_turn_home_offset = _end_turn.offset_top
	_end_turn.pressed.connect(end_turn)
	_continue.pressed.connect(_on_continue_pressed)
	hand_input.bind(self)
	presenter.idle_started.connect(_on_presenter_idle)
	presenter.bind(self, ctl)
	update_piles()


func exit() -> void:
	if top_bar != null:
		top_bar.reclaim_potions()
	presenter.unbind()
	presenter.director = null


## 報酬の背景として残る：入力と再生を止め、操作用の表示を消す。戦場（背景・3D のキャラ・環境エフェクト）は動かしたまま。
func enter_backdrop() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	hand_input.cancel()
	for n: Node in [presenter, hand_input, hand]:
		n.process_mode = Node.PROCESS_MODE_DISABLED
	var t := create_tween().set_parallel(true)
	for c: Control in [hand, arrow, _banner, _own_potions, _energy, _energy_art, _draw_button, _discard_button, _exhaust_button,
			_end_turn, _toast, _result_panel]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.tween_property(c, "modulate:a", 0.0, BACKDROP_FADE)


## 背景の番号。ラン中はシードとマスから決めるので、同じ戦闘を再開しても同じ背景になる（ランの乱数は使わない）。
func backdrop_index() -> int:
	if run == null:
		return randi() % BACKDROPS.size()
	return backdrop_index_of(run)


## ラン中の戦闘の背景の番号（報酬画面も、再起動から再開したときに同じ背景を出すために使う）。
static func backdrop_index_of(p_run: RunController) -> int:
	var s := p_run.state
	return posmod(hash([s.seed_value, s.act_index, s.node_id]), BACKDROPS.size())


# —— 状態のクエリ ——

## 自分の席（協力プレイ）。1 人プレイでは唯一の席。
func me() -> PlayerSeat:
	return ctl.seat_at(my_index) if ctl.seat_at(my_index) != null else ctl.seat_at(0)


func my_unit() -> Combatant:
	return me().unit


## プレイヤーが操作できるか（入力のロック。Architecture §14.4 の LOCKED）。ターン終了・ポーションはこちら（再生が終わるまで待つ）。
func can_act() -> bool:
	return presenter.is_idle() and can_play()


## カードを出せるか。再生中でも、画面がプレイヤーのターンを見せていれば出せる（テンポを止めない。残りの演出は
## try_play が catch_up で片付けてから出す）。敵のターン・カード選択・モーダル・戦闘終了ではロックする。
func can_play() -> bool:
	var c := ctl.combat
	return presenter.player_turn_shown and not _choice_open and (modals == null or modals.is_empty()) and not ctl.is_over() \
			and ctl.pending_choice() == null and c.turn.phase == TurnState.Phase.PLAYER and c.queue.is_empty() \
			and not me().ready and me().is_alive() and not _sending


func combatant(uid: int) -> Combatant:
	var c := ctl.combat
	for s in c.seats:
		if s.unit.uid == uid:
			return s.unit
	for e in c.enemies:
		if e.uid == uid:
			return e
	return null


func unit_view(uid: int) -> UnitView:
	return _units.get(uid)


func find_card(uid: int) -> Card:
	for s in ctl.combat.seats:
		for c in s.piles.all_cards():
			if c.uid == uid:
				return c
	return null


func status_data(id: StringName) -> StatusData:
	return Content.library.status(id) if Content.library != null else null


func move_name(unit: Combatant) -> String:
	return unit.mind.current_move.name if unit.mind != null and unit.mind.current_move != null else ""


## 戦闘中のカード面：[text, cost]。照準中ならその対象で計算する（GameDesign §6.4）。
func card_face(card: Card, target: Combatant = null) -> Array:
	var cost := ctl.cost_of(card, my_index) if card.data.cost_mode == CardData.CostMode.FIXED else -1
	return [ctl.card_text(card, target, UiText.keyword_names(), my_index), cost]


## 生存している敵のうち、立ち絵が pos を含むもの。
func enemy_at(pos: Vector2) -> Combatant:
	for e in ctl.combat.alive_enemies():
		var v := unit_view(e.uid)
		if v != null and v.portrait_rect().has_point(pos):
			return e
	return null


## これより上で離すとプレイ（対象不要のカード）。
func play_line_y() -> float:
	return hand.global_position.y + 60.0


## 対象の無いカードが飛んでいく先。
func play_point() -> Vector2:
	return global_position + Vector2(size.x / 2.0, size.y * 0.42)


func pile_center(pile: String) -> Vector2:
	match pile:
		"draw":
			return _draw_button.get_global_rect().get_center()
		"discard":
			return _discard_button.get_global_rect().get_center()
		"exhaust":
			return _exhaust_button.get_global_rect().get_center()
	return play_point()


func potion_origin() -> Vector2:
	return _potions.get_global_rect().get_center()


# —— コマンド ——

func try_play(card: Card, target: Combatant) -> bool:
	if not can_play():
		return false
	var r := ctl.check_card(card, target, my_index)
	if not r.ok:
		toast(UiText.play_reason(r.reason))
		return false
	presenter.catch_up()
	_send(CoopCommands.PLAY, {card = card.uid, target = target.uid if target != null else -1})
	return true


func try_use_potion(slot: int, target: Combatant) -> bool:
	if not can_act():
		return false
	var r := ctl.check_potion(slot, target, my_index)
	if not r.ok:
		toast(UiText.play_reason(r.reason))
		return false
	_send(CoopCommands.USE_POTION, {slot = slot, target = target.uid if target != null else -1})
	return true


## ターン終了。協力プレイでは Ready（全員が押したら敵のターン）で、押した後にもう一度押すと取り消す。
func end_turn() -> void:
	if ctl.is_coop_ready_pending(my_index):
		if presenter.is_idle() and not _sending:
			_send(CoopCommands.CANCEL_READY, {})
		return
	if not can_act():
		return
	hand_input.cancel()
	_send(CoopCommands.END_TURN, {})


## 戦闘のコマンドを出す（1 人プレイはその場で実行、協力プレイはホストへ送って返事を待つ）。
func _send(op: StringName, args: Dictionary) -> void:
	_sending = Party.coop() and run != null
	Party.act_combat(run, ctl, op, args, _on_sent.bind(op))


func _on_sent(ok: bool, op: StringName) -> void:
	_sending = false
	if not is_inside_tree():
		return
	if not ok:
		if op == CoopCommands.PLAY:
			hand.clear_held()
		toast("ほかの人の操作の後で、もう一度どうぞ" if Party.coop() else "その操作はできません")
	refresh_party()


func request_fast_forward() -> void:
	if not presenter.is_idle():
		presenter.fast_forward = true


## 戦闘の結果が出て、先へ進むのを待っているか（結果のパネル、または勝利後の自動で進むまでの待ち）。
func result_pending() -> bool:
	return _result_panel.visible or _auto_continue


## 戦闘終了後の「続ける」（ラン中なら RunController へ）。勝利後の自動の待ちもこれで飛ばせる。
func continue_after_result() -> void:
	if not result_pending():
		return
	_result_panel.visible = false
	_auto_continue = false
	if run != null:
		Party.act(run, CoopCommands.ACK_COMBAT)
	else:
		sandbox_continue.emit()


# —— View の更新（Presenter からも呼ばれる）——

## プレイヤーのターンが始まった：バナー、エネルギーのオーブを点灯、少し遅れてターン終了ボタンが下から出る（StS2 の録画に合わせた）。
func show_player_turn(turn_no: int) -> void:
	_banner.show_player(turn_no)
	_turn_no = turn_no
	_end_turn.text = "ターン終了 %d" % turn_no
	_slide_end_turn(true)
	_light_energy(true)


## ターン終了を押した：ボタンを下へ引っ込め、オーブを暗くし、敵のターンのバナー。
func show_enemy_turn() -> void:
	_banner.show_enemy()
	_slide_end_turn(false)
	_light_energy(false)


func show_combat_over() -> void:
	_banner.clear()
	_slide_end_turn(false)


func set_energy(value: int, max_value: int) -> void:
	_energy.text = "%d/%d" % [value, max_value]


func update_piles() -> void:
	_draw_button.count = presenter.pile_count("draw")
	_discard_button.count = presenter.pile_count("discard")
	_exhaust_button.count = presenter.pile_count("exhaust")


func show_potions() -> void:
	_potions.show_potions(me().potions)


func float_text(global_pos: Vector2, text: String, color: Color, scale_factor: float = 1.0) -> void:
	Fx.spawn(&"floating_number", global_pos, {text = text, color = color, scale = scale_factor})


## 短い案内（プレイできない理由など）。
func toast(text: String, at: Vector2 = Vector2.INF) -> void:
	_toast.text = text
	_toast.reset_size()
	var center := at if at != Vector2.INF else global_position + Vector2(size.x / 2.0, size.y * 0.55)
	_toast.global_position = center - _toast.size / 2.0 + Vector2(0, -40)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)


## 再生が終わった後、モデルと表示を突き合わせる。
func sync_from_model() -> void:
	var c := ctl.combat
	presenter.sync_locations()
	hand.sync(me().piles.hand, card_face, pile_center("draw"))
	update_piles()
	for unit: Combatant in c.alive_players() + _dead_players() + c.enemies:
		var v := unit_view(unit.uid)
		v.set_hp(unit.hp, unit.max_hp, v.shown_hp != unit.hp)
		v.set_block(unit.block)
		v.set_statuses(unit.statuses.all())
		if not unit.is_alive() and not v.dead:
			v.play_death()
		if presenter.director != null:
			presenter.director.sync_unit(unit)
	set_energy(me().turn.energy, me().turn.energy_max)
	show_potions()
	refresh_party()
	_last_version = -1


func _process(_delta: float) -> void:
	if ctl == null:
		return
	stage.set_speed(presenter.current_speed())
	_banner.set_speed(presenter.current_speed())
	var acting := can_act()
	_end_turn.disabled = not acting and not (ctl.is_coop_ready_pending(my_index) and presenter.is_idle())
	if not presenter.is_idle() and not can_play():
		return
	var aim := hand_input.aim_target()
	if ctl.combat.version != _last_version or aim != _last_aim:
		_refresh_faces(aim)


## カードテキスト・コスト・プレイ可否の表示と、インテントの数字を更新する（Combat.version が変わったときだけ）。
func _refresh_faces(aim: Combatant) -> void:
	_last_version = ctl.combat.version
	_last_aim = aim
	var acting := can_play()
	for v in hand.views():
		var f := card_face(v.card, aim if v == hand_input.view else null)
		v.update_text(f[0], f[1])
		var r := ctl.check_card(v.card, null, my_index)
		var playable := r.ok or r.reason == PlayResult.NEED_TARGET
		v.set_playable(acting and playable)
		v.set_dimmed(not playable and r.reason in [PlayResult.NOT_ENOUGH_ENERGY, PlayResult.UNPLAYABLE, PlayResult.BLOCKED_BY_EFFECT])
	for e in ctl.combat.enemies:
		var uv := unit_view(e.uid)
		if e.is_alive() and not ctl.is_over():
			uv.set_intent(ctl.intent_of(e, my_index), move_name(e))
		else:
			uv.set_intent(null)


func _on_presenter_idle() -> void:
	sync_from_model()
	run_changed.emit()
	if ctl.is_over():
		hand_input.cancel()
		_show_result()
	elif ctl.pending_choice() != null and not _choice_open and ctl.combat.choice_seat() == me():
		_open_choice(ctl.pending_choice())


## 勝利（ラン中）は結果のパネルを出さず、勝利の演出を VICTORY_HOLD 秒見せてから自動で報酬へ進む（StS2 と同じ）。
## 敗北と sandbox はパネルの「続ける」で進む。
func _show_result() -> void:
	if result_pending():
		return
	var victory := ctl.combat.outcome == Combat.Outcome.VICTORY
	if victory and run != null:
		_auto_continue = true
		var t := create_tween()
		t.tween_interval(VICTORY_HOLD)
		t.tween_callback(continue_after_result)
		return
	_result_title.text = "勝利！" if victory else "敗北…"
	_result_info.text = "%d ターン" % me().turn.number
	if victory and me().gold_gained > 0:
		_result_info.text += "　ゴールド +%d" % me().gold_gained
	_result_panel.visible = true


## ターン終了ボタンの出入り。出るときは 0.55 秒待ってから、行き過ぎて戻る動きで下から（END_TURN_DROP px）上がる。
func _slide_end_turn(on: bool) -> void:
	if _end_turn_tween != null and _end_turn_tween.is_valid():
		_end_turn_tween.kill()
	if not on and not _end_turn.visible:
		return   # 隠れている（空の Tween を作るとエンジンのエラーになる）
	var home := _end_turn.get_parent_control().size.y + _end_turn_home_offset
	var t := create_tween()
	_end_turn_tween = t
	if on:
		if not _end_turn.visible:
			_end_turn.visible = true
			_end_turn.modulate.a = 0.0
			_end_turn.position.y = home + END_TURN_DROP
		t.tween_interval(0.55)
		t.tween_property(_end_turn, "position:y", home, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_end_turn, "modulate:a", 1.0, 0.2)
	else:
		t.tween_property(_end_turn, "position:y", home + END_TURN_DROP, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(_end_turn, "modulate:a", 0.0, 0.12)
		t.tween_callback(_end_turn.hide)


## エネルギーのオーブ：敵のターンは暗く沈め、プレイヤーのターンの始めに明るくして小さく弾ませる。
func _light_energy(on: bool) -> void:
	if _energy_tween != null and _energy_tween.is_valid():
		_energy_tween.kill()
	_energy_art.pivot_offset = _energy_art.size / 2.0
	_energy.pivot_offset = _energy.size / 2.0
	var color := Color.WHITE if on else ENERGY_DIM
	var t := create_tween().set_parallel(true)
	_energy_tween = t
	for c: Control in [_energy_art, _energy]:
		t.tween_property(c, "modulate", color, 0.15 if on else 0.25)
		if on:
			c.scale = Vector2.ONE * 1.2
			t.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 戦闘中のカード選択（GameDesign §5.9）。コストは支払い済みなので閉じられない。
func _open_choice(choice: CardChoice) -> void:
	var entries: Array = []
	for card in choice.candidates:
		var f := card_face(card)
		entries.append({data = card.data, text = f[0], card = card, cost = f[1]})
	var title: String = choice.prompt if not choice.prompt.is_empty() else UiText.CHOICE_PROMPTS.get(choice.action, "カードを選ぶ")
	var info := "%d 枚選ぶ" % choice.max_count if choice.min_count == choice.max_count else "最大 %d 枚選ぶ" % choice.max_count
	var modal := open_card_list({title = title, info = info, entries = entries,
			min_count = choice.min_count, max_count = choice.max_count, cancellable = false, showcase = true})
	if modal == null:
		return
	_choice_open = true
	modal.picked.connect(_on_choice_picked.bind(choice))


func _on_choice_picked(indices: PackedInt32Array, choice: CardChoice) -> void:
	_choice_open = false
	var uids: Array = []
	for i in indices:
		uids.append(choice.candidates[i].uid)
	_send(CoopCommands.SUBMIT_CHOICE, {cards = uids})


func _open_pile(pile: Pile.Id) -> void:
	if modals == null or not modals.is_empty():
		return
	hand_input.cancel()
	var cards: Array[Card] = me().piles.pile(pile).duplicate()
	var title := "山札（順番は伏せています）"
	match pile:
		Pile.Id.DRAW:
			cards = CardListModal.sorted_by_name(cards)
		Pile.Id.DISCARD:
			title = "捨て札"
		Pile.Id.EXHAUST:
			title = "廃棄札"
	var entries: Array = []
	for card in cards:
		var f := card_face(card)
		entries.append({data = card.data, text = f[0], card = card, cost = f[1]})
	open_card_list({title = "%s（%d 枚）" % [title, cards.size()], entries = entries})


func _potion_actions(slot: int) -> Array:
	var r := ctl.check_potion(slot, null, my_index)
	var usable := can_act() and (r.ok or r.reason == PlayResult.NEED_TARGET)
	return [[PotionBar.ACTION_USE, "使う", usable], [PotionBar.ACTION_DISCARD, "捨てる", presenter.is_idle() and not ctl.is_over()]]


func _on_potion_action_chosen(slot: int, action: StringName) -> void:
	match action:
		PotionBar.ACTION_USE:
			var potion: PotionData = me().potions[slot] if slot < me().potions.size() else null
			if potion == null or not can_act():
				return
			if potion.aim == CardData.Aim.ENEMY:
				hand_input.begin_potion_aim(slot)
			else:
				try_use_potion(slot, null)
		PotionBar.ACTION_DISCARD:
			if presenter.is_idle() and not ctl.is_over():
				_send(CoopCommands.COMBAT_DISCARD_POTION, {slot = slot})


func _on_continue_pressed() -> void:
	continue_after_result()


# —— 協力プレイ（GameDesign §21）——

## 味方のユニットを自分の後ろ（左）に並べる。遠い人ほど奥（上）で、先に描く。
func _add_allies() -> void:
	var c := ctl.combat
	if not c.is_coop():
		return
	var n := c.seats.size()
	var home := Vector2(_player_view.offset_left, _player_view.offset_top)
	var my_x := minf(home.x + (n - 1) * 86.0, 488.0)
	var shift := my_x - home.x
	_player_view.offset_left += shift
	_player_view.offset_right += shift
	var k := 0
	for s in c.seats:
		if s.index == my_index:
			continue
		k += 1
		var v := UNIT_SCENE.instantiate() as UnitView
		_player_view.get_parent().add_child(v)
		_player_view.get_parent().move_child(v, _player_view.get_index())
		v.offset_left = _player_view.offset_left + ALLY_STEP.x * k
		v.offset_right = _player_view.offset_right + ALLY_STEP.x * k
		v.offset_top = _player_view.offset_top + ALLY_STEP.y * k
		v.offset_bottom = _player_view.offset_bottom + ALLY_STEP.y * k
		v.setup(s.unit)
		_units[s.unit.uid] = v
		stage.add_actor(s.unit.uid, v, ActorCatalog.spec_for_player(), 1.0)
		var tag := Label.new()
		tag.theme_type_variation = &"LabelSmall"
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_theme_color_override(&"font_color", Party.color(s.index))
		tag.add_theme_color_override(&"font_outline_color", Color(0.08, 0.06, 0.05))
		tag.add_theme_constant_override(&"outline_size", 6)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tag)
		_ally_tags[s.unit.uid] = tag
	refresh_party()


func _dead_players() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for s in ctl.combat.seats:
		if not s.unit.is_alive():
			result.append(s.unit)
	return result


## 味方の頭上の印（準備完了 / 戦闘不能。名前は体の下に出ている）と、自分のターン終了ボタンの文言を今の状態に合わせる。
func refresh_party() -> void:
	if ctl == null or not ctl.combat.is_coop():
		return
	for s in ctl.combat.seats:
		var tag: Label = _ally_tags.get(s.unit.uid)
		if tag == null:
			continue
		var text := ""
		if not s.is_alive():
			text = "戦闘不能"
		elif s.ready and ctl.combat.turn.phase == TurnState.Phase.PLAYER:
			text = "✔ 準備完了"
		tag.text = text
		tag.visible = text != ""
		tag.reset_size()
		var v := tag.get_parent_control() as UnitView
		var head := v.portrait_rect()
		tag.position = Vector2(head.position.x - v.global_position.x + (head.size.x - tag.size.x) / 2.0,
				head.position.y - v.global_position.y - tag.size.y)
	if me().ready and ctl.combat.turn.phase == TurnState.Phase.PLAYER and not ctl.is_over():
		_end_turn.text = "待機中（取り消す）"
	else:
		_end_turn.text = "ターン終了 %d" % _turn_no


## 味方がカードを出した：味方の頭上にカードの名前を出す（手札は持たないので、それ以上は見せない）。
func show_ally_card(uid: int, card_id: StringName) -> void:
	var v := unit_view(uid)
	var data := Content.library.card(card_id) if Content.library != null else null
	if v != null and data != null:
		float_text(v.hit_point() + Vector2(0, -80), data.name, Color(0.9, 0.92, 1.0), 0.7)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		request_fast_forward()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"end_turn") and (modals == null or modals.is_empty()):
		end_turn()
		get_viewport().set_input_as_handled()

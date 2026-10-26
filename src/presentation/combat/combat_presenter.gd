class_name CombatPresenter extends Node
## ⑤ Presentation：戦闘のイベントを自分のテンポで再生する（Architecture §14.2）。
## ルール層は同期的に最後まで進めてイベントを出すので、ここで溜めて 1 件ずつ View に振り分ける。
## View の表示値はイベントの snapshot（その時点の値）だけで変え、モデルの最終値を先に見せない。
## 溜まりが無くなったら idle_started を出す。画面はそこでモデルと突き合わせ（sync）、入力を受け付ける。
## 協力プレイ（GameDesign §21）：手札・山・エネルギー・ターンの合図のイベントは自分の席のものだけを再生する。
## 味方のカードは頭上に名前を出すだけ（ダメージ・ブロックなどユニットのイベントは全員分を再生する）。

## 席ごとのイベント（発生源 = その席のプレイヤー）。
const SEAT_EVENTS: Array[CombatEvent.Kind] = [CombatEvent.Kind.TURN_STARTED, CombatEvent.Kind.TURN_ENDING,
		CombatEvent.Kind.TURN_ENDED, CombatEvent.Kind.CARD_DRAWN, CombatEvent.Kind.CARD_PLAYED, CombatEvent.Kind.CARD_DISCARDED,
		CombatEvent.Kind.CARD_EXHAUSTED, CombatEvent.Kind.CARD_CREATED, CombatEvent.Kind.CARD_RETAINED,
		CombatEvent.Kind.CARD_MOVED, CombatEvent.Kind.CARD_UPDATED, CombatEvent.Kind.PILE_SHUFFLED,
		CombatEvent.Kind.ENERGY_CHANGED, CombatEvent.Kind.POTION_USED, CombatEvent.Kind.POTION_DISCARDED,
		CombatEvent.Kind.CHOICE_REQUESTED, CombatEvent.Kind.CHOICE_RESOLVED]

signal idle_started

var pacing: CombatPacing = CombatPacing.new()
## 画面のクリックで 8 倍の早送り（溜まりが無くなったら戻る）。
var fast_forward: bool = false
## テスト用：待たずにすべて再生する（3D の舞台への指示もしない）。
var instant: bool = false
## 3D の舞台への指示役（Architecture §14.6）。null なら 2D の表示だけ。
var director: StageDirector
## 画面がプレイヤーのターンを見せているか（TURN_STARTED を再生してから TURN_ENDING / COMBAT_ENDED を再生するまで）。
## この間は再生中でもカードを出せる（CombatScreen.can_play）。
var player_turn_shown: bool = false

var _screen: CombatScreen
var _ctl: CombatController
var _pending: Array[CombatEvent] = []
var _cooldown: float = 0.0
## 先頭のイベントの前置き（攻撃の振りかぶり）を始め済みか。待ち終わったら前置きなしで再生する。
var _primed: CombatEvent
## 表示上のカードの場所（uid → "draw" / "hand" / "discard" / "exhaust" / "in_play" / "powers"）。山の枚数の表示に使う。
var _loc: Dictionary[int, String] = {}
## TURN_ENDING から TURN_ENDED までを再生中（手札の後始末。捨て札を炎の尾付きで飛ばす）。
var _turn_ending: bool = false


## 戦闘に接続する。これまでに出たイベント（開戦から）も再生する。
func bind(screen: CombatScreen, ctl: CombatController) -> void:
	_screen = screen
	_ctl = ctl
	# 開戦時はデッキのカードがすべて山札にある（シャッフルと天賦の並べ替えはイベントを出さない）。
	for c in screen.me().piles.all_cards():
		_loc[c.uid] = "draw"
	_pending.append_array(ctl.combat.events)
	ctl.event_emitted.connect(_on_event_emitted)


func unbind() -> void:
	if _ctl != null and _ctl.event_emitted.is_connected(_on_event_emitted):
		_ctl.event_emitted.disconnect(_on_event_emitted)
	_ctl = null
	_screen = null


func is_idle() -> bool:
	return _pending.is_empty() and _cooldown <= 0.0


func pending_count() -> int:
	return _pending.size()


func pile_count(pile: String) -> int:
	var n := 0
	for where: String in _loc.values():
		if where == pile:
			n += 1
	return n


## 再生後にモデルの場所で上書きする（ずれの修正）。
func sync_locations() -> void:
	_loc.clear()
	var piles := _screen.me().piles
	for pair: Array in [[piles.draw, "draw"], [piles.hand, "hand"], [piles.discard, "discard"], [piles.exhaust, "exhaust"],
			[piles.in_play, "in_play"], [piles.powers, "powers"]]:
		for c: Card in pair[0]:
			_loc[c.uid] = pair[1]


## 今の再生の倍率（設定の速さ × 溜まりの加速 × 早送り）。3D の舞台のアニメーションにも同じ倍率を掛ける。
func current_speed() -> float:
	return Settings.anim_speed * pacing.backlog_boost(_pending.size()) * (pacing.fast_forward if fast_forward else 1.0)


func _process(delta: float) -> void:
	if _screen == null or (_pending.is_empty() and _cooldown <= 0.0):
		return
	_cooldown -= delta * current_speed()
	while _cooldown <= 0.0 and not _pending.is_empty():
		var e: CombatEvent = _pending.front()
		if director != null and not instant and e != _primed:
			var lead := director.lead_in(e)
			if lead > 0.0:
				_primed = e
				_cooldown += lead
				continue
		_pending.pop_front()
		_primed = null
		_play(e)
		var hold := director.after(e) if director != null and not instant else 0.0
		_cooldown += maxf(pacing.duration_of(e.kind), hold)
	if instant:
		while not _pending.is_empty():
			_play(_pending.pop_front())
		_primed = null
		_cooldown = 0.0
	if _pending.is_empty() and _cooldown <= 0.0:
		_cooldown = 0.0
		fast_forward = false
		idle_started.emit()


## 溜まっている演出を待たずにすべて見せる（再生中に次のカードが出されたとき。Architecture §14.2）。
## 数字は一度に出て、HP などの表示はモデルに追いつく。3D の動作は始めるだけで、次のカードの動作がすぐ上書きする。
func catch_up() -> void:
	while not _pending.is_empty():
		var e: CombatEvent = _pending.pop_front()
		_play(e)
		if director != null and not instant:
			director.after(e)
	_primed = null
	_cooldown = 0.0


func _on_event_emitted(e: CombatEvent) -> void:
	_pending.push_back(e)


## ほかのプレイヤーの席のイベントか。
func _is_ally_event(e: CombatEvent) -> bool:
	return e.kind in SEAT_EVENTS and e.source_uid >= 0 and e.source_uid != _screen.my_unit().uid


func _play(e: CombatEvent) -> void:
	var s := _screen
	if e.kind == CombatEvent.Kind.READY_CHANGED:
		s.refresh_party()
		return
	if _is_ally_event(e):
		if e.kind == CombatEvent.Kind.CARD_PLAYED:
			s.show_ally_card(e.source_uid, e.id)
		elif e.kind in [CombatEvent.Kind.TURN_STARTED, CombatEvent.Kind.TURN_ENDED]:
			s.refresh_party()
		return
	match e.kind:
		CombatEvent.Kind.TURN_STARTED:
			player_turn_shown = true
			s.show_player_turn(e.value)
		CombatEvent.Kind.TURN_ENDING:
			player_turn_shown = false
			_turn_ending = true
			s.show_enemy_turn()
		CombatEvent.Kind.TURN_ENDED:
			player_turn_shown = false
			_turn_ending = false
		CombatEvent.Kind.COMBAT_ENDED:
			player_turn_shown = false
			_turn_ending = false
			s.show_combat_over()
			if e.value == 1:   # 勝利（敗北・中断は 0）
				Fx.spawn(&"victory", Vector2.ZERO)
		CombatEvent.Kind.ENEMY_TURN_STARTED:
			var v := s.unit_view(e.source_uid)
			if v != null:
				v.set_intent(null)
		CombatEvent.Kind.CARD_DRAWN:
			_card_to(e.value, "hand", "draw")
		CombatEvent.Kind.CARD_PLAYED:
			_loc[e.value] = "in_play"
			var v := s.hand.take(e.value)
			if v != null:
				var to := s.unit_view(e.target_uid).hit_point() if e.target_uid >= 0 and s.unit_view(e.target_uid) != null else s.play_point()
				s.hand.release(v, to, &"play")
				Fx.spawn(&"card_burst", to, {color = UiGlyphs.CARD_BURST_COLORS.get(v.card.data.type, Color.WHITE),
						delay = HandView.PLAY_FLIGHT})
		CombatEvent.Kind.CARD_DISCARDED:
			_card_to(e.value, "discard")
		CombatEvent.Kind.CARD_EXHAUSTED:
			_card_to(e.value, "exhaust")
		CombatEvent.Kind.CARD_MOVED:
			_card_to(e.value, String(e.snapshot.get("to", "discard")), String(e.snapshot.get("from", "")))
		CombatEvent.Kind.CARD_CREATED:
			_card_to(e.value, String(e.snapshot.get("to", "discard")), "in_play")
		CombatEvent.Kind.PILE_SHUFFLED:
			for uid: int in _loc.keys():
				if _loc[uid] == "discard":
					_loc[uid] = "draw"
			s.float_text(s.pile_center("draw"), "シャッフル", Color(0.8, 0.85, 1.0), 0.7)
		CombatEvent.Kind.DAMAGED:
			var v := s.unit_view(e.target_uid)
			if v != null:
				v.set_hp(e.snapshot.get("hp", v.shown_hp), e.snapshot.get("max_hp", v.shown_max_hp))
				v.set_block(e.snapshot.get("block", v.shown_block))
				if e.value > 0:
					var kind: DamageEffect.Kind = e.snapshot.get("kind", DamageEffect.Kind.ATTACK)
					s.float_text(v.hit_point(), str(e.value), UiGlyphs.DAMAGE_COLORS.get(kind, Color.WHITE), _severity(e.value, v))
				if e.flags & CombatEvent.FLAG_REVIVED:
					s.float_text(v.hit_point() + Vector2(0, -60), "踏みとどまった！", UiGlyphs.HEAL_COLOR, 0.7)
		CombatEvent.Kind.BLOCKED:
			var v := s.unit_view(e.target_uid)
			if v != null:
				v.set_block(e.snapshot.get("block", 0))
				s.float_text(v.hit_point() + Vector2(-60, 30), "防 %d" % e.value, UiGlyphs.BLOCK_NUMBER_COLOR, 0.7)
		CombatEvent.Kind.HEALED:
			var v := s.unit_view(e.target_uid)
			if v != null:
				v.set_hp(e.snapshot.get("hp", v.shown_hp), e.snapshot.get("max_hp", v.shown_max_hp))
				s.float_text(v.hit_point(), "+%d" % e.value, UiGlyphs.HEAL_COLOR, 0.9)
		CombatEvent.Kind.BLOCK_GAINED:
			var v := s.unit_view(e.target_uid)
			if v != null:
				v.set_block(e.snapshot.get("block", v.shown_block + e.value))
				s.float_text(v.hit_point() + Vector2(0, 40), "ブロック +%d" % e.value, UiGlyphs.BLOCK_NUMBER_COLOR, 0.7)
		CombatEvent.Kind.BLOCK_CLEARED:
			var v := s.unit_view(e.target_uid)
			if v != null:
				v.set_block(0)
		CombatEvent.Kind.STATUS_APPLIED:
			var v := s.unit_view(e.target_uid)
			var data := s.status_data(e.id)
			if v != null and data != null:
				v.set_status(data, e.snapshot.get("stacks", 1))
				if e.value > 0:
					s.float_text(v.hit_point() + Vector2(0, -50), "%s +%d" % [data.name, e.value], UiGlyphs.status_color(data).lightened(0.4), 0.6)
		CombatEvent.Kind.STATUS_REMOVED:
			var v := s.unit_view(e.target_uid)
			if v != null:
				v.remove_status(e.id)
		CombatEvent.Kind.ENERGY_CHANGED:
			s.set_energy(e.value, e.snapshot.get("max", e.value))
		CombatEvent.Kind.INTENT_CHANGED:
			var unit := s.combatant(e.source_uid)
			var v := s.unit_view(e.source_uid)
			if unit != null and v != null and unit.is_alive():
				v.set_intent(_ctl.intent_of(unit, s.my_index), s.move_name(unit))
		CombatEvent.Kind.POTION_USED, CombatEvent.Kind.POTION_DISCARDED:
			s.show_potions()
		CombatEvent.Kind.UNIT_DIED:
			var v := s.unit_view(e.target_uid)
			if v != null:
				v.play_death()
		CombatEvent.Kind.PHASE_CHANGED:
			var v := s.unit_view(e.target_uid)
			if v != null:
				s.float_text(v.hit_point() + Vector2(0, -90), "フェーズ %d" % e.value, Color(1.0, 0.6, 0.3), 0.9)
	s.update_piles()


## カード 1 枚の場所を変え、手札への出入りを View に反映する。from_pile は手札に入るときの飛んでくる元。
func _card_to(uid: int, to: String, from_pile: String = "") -> void:
	var s := _screen
	var was: String = _loc.get(uid, "")
	_loc[uid] = to
	if to == "hand":
		if s.hand.view_of(uid) == null:
			var card := s.find_card(uid)
			if card != null:
				var f := s.card_face(card)
				var origin := s.pile_center(from_pile if not from_pile.is_empty() else was if not was.is_empty() else "draw")
				s.hand.add_card(card, f[0], f[1], origin)
		return
	if was == "hand" or s.hand.view_of(uid) != null:
		var v := s.hand.take(uid)
		if v != null:
			if to == "exhaust":
				s.hand.release(v, Vector2.ZERO, &"exhaust")
			elif _turn_ending and to == "discard":
				s.hand.release(v, s.pile_center(to), &"burn")
			else:
				s.hand.release(v, s.pile_center(to), &"pile")


## 打撃の強さ（ダメージ / 最大 HP）でフローティング数字の大きさを変える（GameDesign §16.2 の基本だけ）。
func _severity(amount: int, v: UnitView) -> float:
	return clampf(0.9 + 1.2 * float(amount) / maxf(1.0, v.shown_max_hp), 0.9, 1.8)

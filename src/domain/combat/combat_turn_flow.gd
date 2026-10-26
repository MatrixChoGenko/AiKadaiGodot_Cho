class_name CombatTurnFlow extends RefCounted
## ③ Domain：ターンの手順（GameDesign §5.2 / §5.4 / §5.5、Architecture §7.6）。
## 各ステップは CallAction として積み、ステップの最後に次のステップを push_bottom する（連鎖）。
## こうすると、あるステップで発生したトリガー（死亡、捨てた時…）は必ず次のステップより先に処理される。
## 協力プレイ（GameDesign §21）：席ごとの処理（ブロック・エネルギー・ドロー・手札の後始末）は席の順に行い、
## 敵の行動のうちプレイヤーを狙う効果は生存している全員に 1 回ずつ当てる。1 人プレイでは従来と同じ順序になる。

## Combat が自分を持っているので、循環参照にならないよう弱参照で持つ。
var _c: Combat:
	get:
		return _combat_ref.get_ref() as Combat
var _combat_ref: WeakRef


func _init(combat: Combat) -> void:
	_combat_ref = weakref(combat)


func _next(step: Callable) -> void:
	_c.queue.push_bottom(CallAction.new(step))


func _alive_seats() -> Array[PlayerSeat]:
	var result: Array[PlayerSeat] = []
	for s in _c.seats:
		if s.is_alive():
			result.append(s)
	return result


# —— プレイヤーのターン開始（§5.2）——

func begin_player_turn() -> void:
	_next(_turn_start)


func _turn_start() -> void:
	_c.set_phase(TurnState.Phase.SETUP)
	for s in _c.seats:
		s.turn.start_turn()
		s.ready = not s.is_alive()
	if _c.seats[0].turn.number > _c.config.turn_limit:
		_c.end_combat(Combat.Outcome.DEFEAT)   # 無限ループ防止
		return
	for s in _alive_seats():
		_c.focus(s)
		var t := s.turn
		# 第 1 ターンはブロックを消さない（戦闘開始時に得たブロックを残す。GameDesign 付録 C の C1）。
		if t.number > 1:
			_c.clear_block(s.unit)
		var energy := HookCalc.make(s.energy_per_turn, s.unit)
		_c.hooks.modify(CombatBehavior.Hook.TURN_ENERGY, energy)
		t.energy = maxi(energy.amount, 0)
		t.energy_max = t.energy
		_c.emit(CombatEvent.Kind.TURN_STARTED, s.unit, null, t.number)
		_c.emit(CombatEvent.Kind.ENERGY_CHANGED, s.unit, null, t.energy, &"", 0, {max = t.energy_max})
		_c.hooks.notify(CombatBehavior.Hook.TURN_START, s.unit)
	_next(_turn_start_deferred)


func _turn_start_deferred() -> void:
	_c.run_deferred(DeferEffect.Timing.START_OF_NEXT_TURN)
	_next(_turn_start_decay)


func _turn_start_decay() -> void:
	decay(StatusData.Decay.CLEAR_AT_TURN_START)
	_next(_turn_start_draw)


func _turn_start_draw() -> void:
	for s in _alive_seats():
		_c.focus(s)
		var draw := HookCalc.make(s.draw_per_turn, s.unit)
		_c.hooks.modify(CombatBehavior.Hook.TURN_DRAW, draw)
		_c.draw_cards(maxi(draw.amount, 0))
	_next(_turn_start_intents)


func _turn_start_intents() -> void:
	_c.choose_intents()
	_c.set_phase(TurnState.Phase.PLAYER)


# —— プレイヤーのターン終了（§5.4）——

func end_player_turn() -> void:
	# ここからラウンド終了までに付与されたスタックは、そのラウンドの減衰を受けない（疑念の弱体なども次のターンに効く）。
	_c.set_phase(TurnState.Phase.ENEMY)
	for s in _alive_seats():
		_c.emit(CombatEvent.Kind.TURN_ENDING, s.unit, null, s.turn.number)
	_next(_turn_end_hooks)


func _turn_end_hooks() -> void:
	_c.hooks.notify(CombatBehavior.Hook.TURN_END, _c.lead_player())   # 毒・再生（全ユニット）
	_next(_turn_end_deferred)


func _turn_end_deferred() -> void:
	_c.run_deferred(DeferEffect.Timing.END_OF_THIS_TURN)
	_next(_turn_end_decay)


func _turn_end_decay() -> void:
	decay(StatusData.Decay.CLEAR_AT_TURN_END)
	_next(_turn_end_hand_effects)


func _turn_end_hand_effects() -> void:
	for s in _alive_seats():
		for card in s.piles.hand.duplicate():
			if not card.data.end_of_turn_in_hand.is_empty():
				_c.queue.push_bottom(TriggerCardAction.new(card, card.data.end_of_turn_in_hand, s))
	_next(_turn_end_cleanup)


## 手札の後始末：エセリアル → 廃棄、保留 → 残して保留ターン数 +1、それ以外 → 捨てる（捨てられた時が発動する）。
func _turn_end_cleanup() -> void:
	for s in _alive_seats():
		_c.focus(s)
		for card in s.piles.hand.duplicate():
			if card.has_keyword(CardData.Keyword.ETHEREAL):
				_c.exhaust_card(card)
			elif card.has_keyword(CardData.Keyword.RETAIN) or card.retain_this_turn:
				card.retained_turns += 1
				_c.emit(CombatEvent.Kind.CARD_RETAINED, s.unit, null, card.uid, card.data.id)
			else:
				_c.discard_from_hand(card)
		for card in s.piles.all_cards():
			card.retain_this_turn = false
			card.cost_delta_turn = 0
		_c.emit(CombatEvent.Kind.TURN_ENDED, s.unit, null, s.turn.number)
	_next(_enemy_act.bind(0))


# —— 敵のターン（§5.5）——

func _enemy_act(index: int) -> void:
	if index >= _c.enemies.size():
		_next(_round_end)
		return
	var e := _c.enemies[index]
	if e.is_alive() and not _c.alive_players().is_empty():
		# id と intent は表現層用（どの行動の動作を見せるか。行動の後には current_move が次の行動に変わっている）。
		var current := e.mind.current_move
		_c.emit(CombatEvent.Kind.ENEMY_TURN_STARTED, e, null, index, current.id if current != null else &"", 0,
				{intent = _c.intent_of(e, _c.lead_player()).kind})
		_c.clear_block(e)
		_c.hooks.notify(CombatBehavior.Hook.TURN_START, e)
		var move := e.mind.current_move
		if move != null:
			e.mind.record(move)
			_push_move(e, move)
	_next(_enemy_act.bind(index + 1))


## 敵の行動を積む。1 人プレイ（席が 1 つ）なら全効果を 1 つの現場で。
## 協力プレイでは、プレイヤーを狙う効果（選んだ対象 = プレイヤー、プレイヤーの山に触れる効果）を生存者全員に 1 回ずつ当て、
## それ以外（自分へのブロック・強化など）は 1 回だけ。効果の並び順は保つ。
func _push_move(e: Combatant, move: EnemyMove) -> void:
	var lead_ctx := _c.make_context(e, _c.lead_player(), null)
	if not _c.is_coop():
		_c.push_effects(move.effects, lead_ctx)
		return
	var per_seat: Dictionary[PlayerSeat, EffectContext] = {}
	for s in _alive_seats():
		per_seat[s] = lead_ctx if s.unit == lead_ctx.chosen else _c.make_context(e, s.unit, null)
	var actions: Array[CombatAction] = []
	for effect in move.effects:
		if effect == null:
			continue
		if aims_at_players(effect):
			for s: PlayerSeat in per_seat:
				actions.append(ResolveEffectAction.new(effect, per_seat[s]))
		else:
			actions.append(ResolveEffectAction.new(effect, lead_ctx))
	_c.queue.push_top_many(actions)


## 敵の効果がプレイヤーを狙うか（効果ツリーを children() で辿る。Architecture §21 ルール 12）。
static func aims_at_players(effect: CardEffect) -> bool:
	if effect == null:
		return false
	if effect.target is ChosenTarget:
		return true
	if effect.target == null and (effect is CreateCardEffect or effect is DiscardEffect or effect is ExhaustEffect
			or effect is ChooseCardsEffect or effect is ModifyCostEffect):
		return true
	for child in effect.children():
		if aims_at_players(child):
			return true
	return false


## ラウンド終了：全員の行動が終わった。「ラウンド終了時に -1」の減衰を処理して、次のプレイヤーのターンへ。
func _round_end() -> void:
	_c.hooks.notify(CombatBehavior.Hook.ROUND_END)
	decay(StatusData.Decay.LOSE_ONE_AT_ROUND_END)
	for unit in _c.alive_units():
		for stack in unit.statuses.all():
			stack.fresh = false
	begin_player_turn()


## 指定の減衰ルールを全ユニットに適用する。
func decay(rule: StatusData.Decay) -> void:
	for unit in _c.alive_units():
		for stack in unit.statuses.all().duplicate():
			if stack.data.decay != rule:
				continue
			if rule == StatusData.Decay.LOSE_ONE_AT_ROUND_END:
				if stack.fresh:
					continue   # 敵のターン中に付与されたスタックは、このラウンドは減らない
				_c.reduce_stacks(stack, 1)
			else:
				_c.reduce_stacks(stack, stack.stacks)

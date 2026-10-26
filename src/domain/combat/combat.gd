class_name Combat extends RefCounted
## ③ Domain：戦闘エンジン（Architecture §7）。
## 戦闘を変化させる処理はすべて ActionQueue を通し、起きたことは CombatEvent として書き出す（読み返さない）。
## 外部（UI / テスト / ボット）は CombatController 経由でだけ操作する。ターンの手順は CombatTurnFlow にある。

signal event_emitted(event: CombatEvent)

enum Outcome { NONE, VICTORY, DEFEAT, ABORTED }

## プレイヤーの席（協力プレイでは 2〜4。1 人プレイでは 1）。
var seats: Array[PlayerSeat] = []
## いま処理している席。コマンド・ターンの手順・キューの処理がそれぞれ明示的に切り替える（focus）。
## 下の player / piles / turn / relics / potions / gold_gained / energy_per_turn / draw_per_turn はこの席のもの。
## 表現層が読むときは席を明示する（focus を当てにしない）。
var seat: PlayerSeat
var player: Combatant:
	get:
		return seat.unit
var piles: Piles:
	get:
		return seat.piles
var turn: TurnState:
	get:
		return seat.turn
var relics: Array[RelicSlot]:
	get:
		return seat.relics
## ポーション枠。空きは null。
var potions: Array[PotionData]:
	get:
		return seat.potions
var gold_gained: int:
	get:
		return seat.gold_gained
	set(value):
		seat.gold_gained = value
var energy_per_turn: int:
	get:
		return seat.energy_per_turn
	set(value):
		seat.energy_per_turn = value
var draw_per_turn: int:
	get:
		return seat.draw_per_turn
	set(value):
		seat.draw_per_turn = value
var enemies: Array[Combatant] = []
var queue: ActionQueue = ActionQueue.new()
var hooks: HookDispatcher
var rng: RngStreams
var config: RunConfig
var flow: CombatTurnFlow
## null 以外 = プレイヤーのカード選択待ち（どの席の選択かは pending_choice.ctx.source）。
var pending_choice: CardChoice
var chooser: AutoChooser = AutoChooser.new()
## 人間が操作しているか（false ならカード選択で止まらない）。
var interactive: bool = true
var events: Array[CombatEvent] = []
## イベントを出すたびに +1。UI はこれを見て派生データを再計算するか決める。
var version: int = 0
var outcome: Outcome = Outcome.NONE
## 戦闘中に生成したカードの枚数（カード枚数の保存の検査に使う）。
var created_count: int = 0

var _deferred: Dictionary[int, Array] = {}   # DeferEffect.Timing -> [[effects, ctx], ...]
var _next_card_uid: int = 1

## 協力プレイで 2 人目以降のプレイヤーのユニットの uid（敵の uid 1〜と重ならないように）。
const SEAT_UID_BASE: int = 100


static func create(setup: CombatSetup) -> Combat:
	var c := Combat.new()
	c.config = setup.config
	c.rng = setup.rng
	c.interactive = setup.interactive
	c.hooks = HookDispatcher.new(c)
	c.flow = CombatTurnFlow.new(c)
	var seat_setups := setup.seats
	if seat_setups.is_empty():
		var one := CombatSeatSetup.new()
		one.name = setup.player_name
		one.hp = setup.player_hp
		one.max_hp = setup.player_max_hp
		one.energy_per_turn = setup.energy_per_turn
		one.draw_per_turn = setup.draw_per_turn
		one.deck = setup.deck
		one.relics = setup.relics
		one.potions = setup.potions
		seat_setups = [one]
	for i in seat_setups.size():
		var ss := seat_setups[i]
		var s := PlayerSeat.new()
		s.index = i
		s.unit = Combatant.new(0 if i == 0 else SEAT_UID_BASE + i, Combatant.Side.PLAYER, ss.name, ss.hp, ss.max_hp)
		s.relics = ss.relics
		s.potions = ss.potions.duplicate()
		s.energy_per_turn = ss.energy_per_turn
		s.draw_per_turn = ss.draw_per_turn
		s.deck = ss.deck
		s.keep_deck_order = setup.keep_deck_order
		for relic in s.relics:
			relic.owner = s.unit
		for card in ss.deck:
			c._next_card_uid = maxi(c._next_card_uid, card.uid + 1)
		c.seats.append(s)
	c.seat = c.seats[0]
	# 敵の HP は人数で増やす（GameDesign §21：1 人増えるごとに +coop_enemy_hp_percent %）。
	var hp_percent := 100 + c.config.coop_enemy_hp_percent * (c.seats.size() - 1)
	for i in setup.encounter.enemies.size():
		var data := setup.encounter.enemies[i]
		var hp := setup.fixed_enemy_hp if setup.fixed_enemy_hp > 0 else c.rng.range_int(&"combat", data.hp_min, data.hp_max)
		hp = maxi(hp * hp_percent / 100, 1)
		var e := Combatant.new(i + 1, Combatant.Side.ENEMY, data.name, hp, hp)
		e.data = data
		e.mind = EnemyMind.new()
		c.enemies.append(e)
	return c


## 戦闘を始める（GameDesign §5.1）。第 1 ターンのドローとインテントの決定まで進めて止まる。
func start() -> void:
	emit(CombatEvent.Kind.COMBAT_STARTED)
	for e in enemies:
		for status: StatusData in e.data.starting_statuses:
			apply_status(e, e, status, e.data.starting_statuses[status])
	for s in seats:
		focus(s)
		for card in s.deck:
			card.reset_combat_mods()
			piles.draw.append(card)
		if not s.keep_deck_order:
			rng.shuffle(&"draw", piles.draw)
		# 天賦は山札の一番上（配列の末尾）へ。順番は保つ。
		var innate: Array[Card] = []
		for card in piles.draw:
			if card.has_keyword(CardData.Keyword.INNATE):
				innate.append(card)
		for card in innate:
			piles.draw.erase(card)
		piles.draw.append_array(innate)
	focus(seats[0])
	hooks.notify(CombatBehavior.Hook.COMBAT_START)
	flow.begin_player_turn()
	queue.run(self)


func is_over() -> bool:
	return outcome != Outcome.NONE


# —— 席（協力プレイ）——

func is_coop() -> bool:
	return seats.size() > 1


## 処理する席を切り替える。前の席を返す（表現層が一時的に切り替えて戻すとき用）。
func focus(s: PlayerSeat) -> PlayerSeat:
	var before := seat
	if s != null:
		seat = s
	return before


func focus_index(index: int) -> PlayerSeat:
	return focus(seats[index] if index >= 0 and index < seats.size() else null)


func seat_of(unit: Combatant) -> PlayerSeat:
	for s in seats:
		if s.unit == unit:
			return s
	return null


## カードを持っている席（山・手札・プレイ中のどこかにある）。
func seat_of_card(card: Card) -> PlayerSeat:
	for s in seats:
		if s.piles.location_of(card) != "none":
			return s
	return null


## 効果の現場が属する席に切り替える：発動者がプレイヤーならその席、敵の行動なら狙われたプレイヤーの席。
func focus_ctx(ctx: EffectContext) -> void:
	if ctx == null:
		return
	if ctx.source != null and ctx.source.is_player():
		focus(seat_of(ctx.source))
	elif ctx.chosen != null and ctx.chosen.is_player():
		focus(seat_of(ctx.chosen))


func alive_players() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for s in seats:
		if s.unit.is_alive():
			result.append(s.unit)
	return result


## 敵の行動で「プレイヤー」として使う 1 人（席の順で最初の生存者。どの PC でも同じ結果になるように focus を使わない）。
func lead_player() -> Combatant:
	for s in seats:
		if s.unit.is_alive():
			return s.unit
	return seats[0].unit


## フェーズは全席で同じ値にする。
func set_phase(p: TurnState.Phase) -> void:
	for s in seats:
		s.turn.phase = p


# —— ユニット ——

func opponents_of(unit: Combatant) -> Array[Combatant]:
	if unit == null or unit.is_player():
		return alive_enemies()
	return alive_players()


## 味方：プレイヤーは自分だけ（協力プレイでも味方を対象にする効果は無い。GameDesign §21）。
func allies_of(unit: Combatant) -> Array[Combatant]:
	if unit == null or unit.is_player():
		var who := unit if unit != null else player
		var result: Array[Combatant] = []
		if who.is_alive():
			result.append(who)
		return result
	return alive_enemies()


func alive_enemies() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for e in enemies:
		if e.is_alive():
			result.append(e)
	return result


func alive_units() -> Array[Combatant]:
	var result := alive_players()
	result.append_array(alive_enemies())
	return result


# —— ダメージ・ブロック・回復（Architecture §7.7。ダメージの入り口はここだけ）——

func deal_damage(calc: DamageCalc) -> DamageCalc:
	var t := calc.target
	if t == null or not t.is_alive() or calc.amount <= 0:
		return calc   # 基本値 0 以下は補正をかけずに何もしない（GameDesign 付録 C の C10）
	_modify_damage(calc)
	var amount := maxi(calc.amount, 0)
	if not calc.pierce_block and t.block > 0 and amount > 0:
		calc.blocked = mini(t.block, amount)
		t.block -= calc.blocked
		amount -= calc.blocked
		emit(CombatEvent.Kind.BLOCKED, calc.source, t, calc.blocked, &"", 0, {block = t.block, kind = calc.kind})
	var flags := 0
	if amount >= t.hp and amount > 0:
		hooks.modify(CombatBehavior.Hook.LETHAL, calc)
		if calc.lethal_prevented:
			calc.hp_lost = t.hp - 1
			t.hp = 1
			flags |= CombatEvent.FLAG_REVIVED
		else:
			flags |= CombatEvent.FLAG_LETHAL
			if amount > t.hp:
				flags |= CombatEvent.FLAG_OVERKILL
			calc.hp_lost = t.hp
			t.hp = 0
	else:
		calc.hp_lost = amount
		t.hp -= amount
	emit(CombatEvent.Kind.DAMAGED, calc.source, t, calc.hp_lost, &"", flags,
		{hp = t.hp, block = t.block, kind = calc.kind, max_hp = t.max_hp})
	if calc.lethal_prevented and calc.revive_heal > 0:
		heal(t, calc.revive_heal)
	hooks.notify(CombatBehavior.Hook.DAMAGED, calc)
	if t.hp <= 0:
		calc.killed = true
		queue.push_bottom(DeathAction.new(t))
	elif not t.is_player():
		_check_phase(t)
	return calc


## 表示用のダメージ（カード面の数字・インテント）。deal_damage と同じ補正を通すので表示 == 実際になる。
func preview_damage(source: Combatant, target: Combatant, base: int, kind: DamageEffect.Kind) -> int:
	if base <= 0:
		return 0
	var calc := DamageCalc.new(base, kind, source, target)
	calc.preview = true
	_modify_damage(calc)
	return maxi(calc.amount, 0)


func _modify_damage(calc: DamageCalc) -> void:
	hooks.modify(CombatBehavior.Hook.OUTGOING_DAMAGE, calc)
	hooks.modify(CombatBehavior.Hook.INCOMING_DAMAGE, calc)


## HP を失う（ブロック無視・補正なし。起死回生は効く）。
func lose_hp(unit: Combatant, amount: int, source: Combatant = null) -> DamageCalc:
	var calc := DamageCalc.new(amount, DamageEffect.Kind.HP_LOSS, source, unit)
	calc.pierce_block = true
	return deal_damage(calc)


## ダメージを今の一連の処理の後に予約する（トゲの反撃など。再帰しない）。
## キューに積む Callable は（self を捕まえるラムダではなく）メソッドの bind にする。ラムダだと循環参照になる。
func schedule_damage(source: Combatant, target: Combatant, amount: int, kind: DamageEffect.Kind) -> void:
	queue.push_bottom(CallAction.new(_scheduled_damage.bind(DamageCalc.new(amount, kind, source, target))))


func _scheduled_damage(calc: DamageCalc) -> void:
	deal_damage(calc)


func gain_block(unit: Combatant, amount: int, preview: bool = false) -> int:
	if unit == null or not unit.is_alive():
		return 0
	var calc := HookCalc.make(amount, unit, preview)
	hooks.modify(CombatBehavior.Hook.BLOCK_GAIN, calc)
	var n := maxi(calc.amount, 0)
	if preview or n == 0:
		return n
	unit.block += n
	emit(CombatEvent.Kind.BLOCK_GAINED, unit, unit, n, &"", 0, {block = unit.block})
	return n


func clear_block(unit: Combatant) -> void:
	if unit.block == 0:
		return
	var calc := HookCalc.make(unit.block, unit)
	hooks.modify(CombatBehavior.Hook.BLOCK_CLEAR, calc)
	if calc.cancelled:
		return
	unit.block = 0
	emit(CombatEvent.Kind.BLOCK_CLEARED, unit, unit, 0, &"", 0, {block = 0})


func heal(unit: Combatant, amount: int, preview: bool = false) -> int:
	if unit == null or not unit.is_alive():
		return 0
	var calc := HookCalc.make(amount, unit, preview)
	hooks.modify(CombatBehavior.Hook.HEAL, calc)
	var n := clampi(calc.amount, 0, unit.max_hp - unit.hp)
	if preview or n == 0:
		return n
	unit.hp += n
	emit(CombatEvent.Kind.HEALED, unit, unit, n, &"", 0, {hp = unit.hp, max_hp = unit.max_hp})
	return n


func gain_energy(amount: int) -> void:
	turn.energy = maxi(turn.energy + amount, 0)
	emit(CombatEvent.Kind.ENERGY_CHANGED, player, null, turn.energy, &"", 0, {max = turn.energy_max})


# —— ステータス ——

## ステータスを付与する。実際に増えたスタック数を返す（アーティファクトで打ち消されたら 0）。
func apply_status(source: Combatant, target: Combatant, status: StatusData, stacks: int) -> int:
	if target == null or not target.is_alive() or stacks == 0:
		return 0
	var calc := HookCalc.make(stacks, target)
	calc.source = source
	calc.status = status
	hooks.modify(CombatBehavior.Hook.STATUS_APPLY, calc)
	if calc.cancelled or calc.amount == 0:
		return 0
	var stack := target.statuses.find(status)
	if stack == null:
		stack = StatusStack.new(status, target, 0)
		target.statuses.add(stack)
	var before := stack.stacks
	stack.stacks = clampi(stack.stacks + calc.amount, 0, status.max_stacks)
	if turn.phase == TurnState.Phase.ENEMY:
		stack.fresh = true
	var delta := stack.stacks - before
	if stack.stacks == 0:
		target.statuses.remove(stack)
		emit(CombatEvent.Kind.STATUS_REMOVED, source, target, 0, status.id)
	else:
		emit(CombatEvent.Kind.STATUS_APPLIED, source, target, delta, status.id, 0, {stacks = stack.stacks})
	hooks.notify(CombatBehavior.Hook.STATUS_APPLIED, calc)
	return delta


## スタックを減らす（0 になれば取り除く）。Behavior の自己減衰や消費に使う。
func reduce_stacks(stack: StatusStack, amount: int) -> void:
	if amount <= 0 or not stack.owner.statuses.all().has(stack):
		return
	stack.stacks = maxi(stack.stacks - amount, 0)
	if stack.stacks == 0:
		stack.owner.statuses.remove(stack)
		emit(CombatEvent.Kind.STATUS_REMOVED, null, stack.owner, 0, stack.data.id)
	else:
		emit(CombatEvent.Kind.STATUS_APPLIED, null, stack.owner, -amount, stack.data.id, 0, {stacks = stack.stacks})


func remove_statuses(unit: Combatant, polarity: StatusData.Polarity) -> void:
	for stack in unit.statuses.all().duplicate():
		if stack.data.polarity == polarity:
			reduce_stacks(stack, stack.stacks)


## Behavior が実際に発動したことを知らせる（レリックの発光など）。プレビュー / 補正の経路では呼ばない。
func notify_triggered(host: BehaviorHost) -> void:
	var kind := CombatEvent.Kind.RELIC_TRIGGERED if host.is_relic() else CombatEvent.Kind.STATUS_TRIGGERED
	emit(kind, host.owner, host.owner, 0, host.id())


# —— カード ——

func cost_of(card: Card) -> int:
	match card.data.cost_mode:
		CardData.CostMode.X:
			return turn.energy
		CardData.CostMode.UNPLAYABLE:
			return -1
	var calc := HookCalc.make(maxi(card.data.cost + card.cost_delta_combat + card.cost_delta_turn, 0))
	calc.card = card
	calc.preview = true
	hooks.modify(CombatBehavior.Hook.CARD_COST, calc)
	return maxi(calc.amount, 0)


## n 枚引く。山札が空なら捨て札をシャッフルして戻す。手札がいっぱいなら捨て札へ。実際に手札に入った枚数を返す。
func draw_cards(n: int) -> int:
	var drawn := 0
	for i in n:
		if piles.draw.is_empty():
			if piles.discard.is_empty():
				break
			_reshuffle_discard()
		var card: Card = piles.draw.pop_back()
		if piles.hand.size() >= config.hand_limit:
			piles.discard.append(card)
			emit(CombatEvent.Kind.CARD_MOVED, player, null, card.uid, card.data.id, 0, {to = "discard", from = "draw"})
			continue
		piles.hand.append(card)
		card.retained_turns = 0
		drawn += 1
		emit(CombatEvent.Kind.CARD_DRAWN, player, null, card.uid, card.data.id)
		if not card.data.on_draw.is_empty():
			queue.push_bottom(TriggerCardAction.new(card, card.data.on_draw, seat))
	return drawn


func _reshuffle_discard() -> void:
	var n := piles.discard.size()
	piles.draw.append_array(piles.discard)
	piles.discard.clear()
	rng.shuffle(&"draw", piles.draw)
	emit(CombatEvent.Kind.PILE_SHUFFLED, player, null, n)


## 手札から捨てる（「捨てられた時」を発動する）。
func discard_from_hand(card: Card) -> void:
	if not piles.hand.has(card):
		return
	piles.hand.erase(card)
	piles.discard.append(card)
	emit(CombatEvent.Kind.CARD_DISCARDED, player, null, card.uid, card.data.id)
	if not card.data.on_discard.is_empty():
		queue.push_bottom(TriggerCardAction.new(card, card.data.on_discard, seat))


## 廃棄する（どこにあっても。「廃棄された時」を必ず発動する。廃棄札に入った後で発動）。
func exhaust_card(card: Card) -> void:
	var from := piles.location_of(card)
	piles.take(card)
	piles.exhaust.append(card)
	emit(CombatEvent.Kind.CARD_EXHAUSTED, player, null, card.uid, card.data.id, 0, {from = from})
	if not card.data.on_exhaust.is_empty():
		queue.push_bottom(TriggerCardAction.new(card, card.data.on_exhaust, seat))


## カードを指定の場所へ動かす（トリガーなし。廃棄だけは exhaust_card と同じ）。
func move_card(card: Card, place: Pile.Place) -> void:
	if place == Pile.Place.EXHAUST:
		exhaust_card(card)
		return
	var from := piles.location_of(card)
	piles.take(card)
	var to := _put(card, place)
	emit(CombatEvent.Kind.CARD_MOVED, player, null, card.uid, card.data.id, 0, {from = from, to = to})


## 新しいカードを作って置く。
func create_cards(data: CardData, place: Pile.Place, count: int, temporary: bool, upgraded: bool) -> Array[Card]:
	var made: Array[Card] = []
	var card_data := data.upgraded if upgraded and data.upgraded != null else data
	for i in count:
		var card := Card.new(_next_card_uid, card_data, temporary)
		_next_card_uid += 1
		created_count += 1
		var to := _put(card, place)
		emit(CombatEvent.Kind.CARD_CREATED, player, null, card.uid, card.data.id, 0, {to = to})
		made.append(card)
	return made


## 置き場所に入れる（手札がいっぱいなら捨て札）。入れた山の名前を返す。
func _put(card: Card, place: Pile.Place) -> String:
	match place:
		Pile.Place.HAND:
			if piles.hand.size() >= config.hand_limit:
				piles.discard.append(card)
				return "discard"
			piles.hand.append(card)
			card.retained_turns = 0
			return "hand"
		Pile.Place.DRAW_TOP:
			piles.draw.append(card)
			return "draw"
		Pile.Place.DRAW_BOTTOM:
			piles.draw.insert(0, card)
			return "draw"
		Pile.Place.DRAW_RANDOM:
			piles.draw.insert(rng.range_int(&"draw", 0, piles.draw.size()), card)
			return "draw"
		Pile.Place.EXHAUST:
			piles.exhaust.append(card)
			return "exhaust"
		_:
			piles.discard.append(card)
			return "discard"


func touch_card(card: Card) -> void:
	emit(CombatEvent.Kind.CARD_UPDATED, player, null, card.uid, card.data.id)


# —— プレイ ——

func check_card(card: Card, target: Combatant = null) -> PlayResult:
	var r := _check_turn()
	if not r.ok:
		return r
	if not piles.hand.has(card):
		return PlayResult.fail(PlayResult.NOT_IN_HAND)
	if card.data.cost_mode == CardData.CostMode.UNPLAYABLE:
		return PlayResult.fail(PlayResult.UNPLAYABLE)
	if cost_of(card) > turn.energy:
		return PlayResult.fail(PlayResult.NOT_ENOUGH_ENERGY)
	if card.data.aim == CardData.Aim.ENEMY:
		if target == null:
			return PlayResult.fail(PlayResult.NEED_TARGET)
		if target.is_player() or not target.is_alive():
			return PlayResult.fail(PlayResult.INVALID_TARGET)
	var ctx := make_preview_context(player, target, card)
	for e in card.data.on_play:
		if not e.can_apply(ctx):
			return PlayResult.fail(PlayResult.BLOCKED_BY_EFFECT)
	return PlayResult.success()


func play_card(card: Card, target: Combatant = null) -> PlayResult:
	var r := check_card(card, target)
	if not r.ok:
		return r
	var plays_calc := HookCalc.make(1)
	plays_calc.card = card
	hooks.modify(CombatBehavior.Hook.PLAY_COUNT, plays_calc)
	var plays := clampi(plays_calc.amount, 1, config.echo_limit)
	var spent := cost_of(card)
	turn.energy -= spent
	emit(CombatEvent.Kind.ENERGY_CHANGED, player, null, turn.energy, &"", 0, {max = turn.energy_max})
	piles.hand.erase(card)   # 先に手札から外し、「手札をすべて捨てる」に自分が含まれないようにする
	piles.in_play.append(card)
	turn.played_types.append(card.data.type)
	if card.data.aim != CardData.Aim.ENEMY:
		target = null
	emit(CombatEvent.Kind.CARD_PLAYED, player, target, card.uid, card.data.id, 0, {plays = plays, cost = spent})
	hooks.notify(CombatBehavior.Hook.CARD_PLAYED, card)
	var stats := ResolveStats.new()
	var actions: Array[CombatAction] = []
	for i in plays:
		actions.append_array(effect_actions(card.data.on_play, make_context(player, target, card, spent, stats)))
	actions.append(CallAction.new(_finish_play.bind(card, seat)))
	queue.push_top_many(actions)
	queue.run(self)
	return PlayResult.success()


## プレイ後の行き先（GameDesign §5.3）：パワーは戦闘から除外、廃棄 / 一時カードは廃棄札、それ以外は捨て札（Behavior で書き換え可）。
func _finish_play(card: Card, s: PlayerSeat) -> void:
	focus(s)
	if not piles.in_play.has(card):
		return   # 解決中に別の場所へ動かされた
	# 行き先は CARD_MOVED（廃棄は CARD_EXHAUSTED）で知らせる。表現層はこれでカードの行き先と山の枚数を追う。
	if card.data.type == CardData.Type.POWER:
		piles.in_play.erase(card)
		piles.powers.append(card)
		emit(CombatEvent.Kind.CARD_MOVED, player, null, card.uid, card.data.id, 0, {from = "in_play", to = "powers"})
	else:
		var calc := HookCalc.make(0)
		calc.card = card
		calc.place = Pile.Place.EXHAUST if card.has_keyword(CardData.Keyword.EXHAUST) or card.temporary else Pile.Place.DISCARD
		hooks.modify(CombatBehavior.Hook.CARD_DESTINATION, calc)
		if calc.place == Pile.Place.EXHAUST:
			exhaust_card(card)
		else:
			piles.in_play.erase(card)
			var to := _put(card, calc.place as Pile.Place)
			emit(CombatEvent.Kind.CARD_MOVED, player, null, card.uid, card.data.id, 0, {from = "in_play", to = to})
	turn.last_type = card.data.type
	hooks.notify(CombatBehavior.Hook.CARD_RESOLVED, card)


func check_potion(slot: int, target: Combatant = null) -> PlayResult:
	var r := _check_turn()
	if not r.ok:
		return r
	if slot < 0 or slot >= potions.size() or potions[slot] == null:
		return PlayResult.fail(PlayResult.NO_POTION)
	if potions[slot].aim == CardData.Aim.ENEMY:
		if target == null:
			return PlayResult.fail(PlayResult.NEED_TARGET)
		if target.is_player() or not target.is_alive():
			return PlayResult.fail(PlayResult.INVALID_TARGET)
	return PlayResult.success()


func use_potion(slot: int, target: Combatant = null) -> PlayResult:
	var r := check_potion(slot, target)
	if not r.ok:
		return r
	var potion := potions[slot]
	potions[slot] = null   # 先に所持品から外してから解決する
	if potion.aim != CardData.Aim.ENEMY:
		target = null
	emit(CombatEvent.Kind.POTION_USED, player, target, slot, potion.id)
	queue.push_top_many(effect_actions(potion.effects, make_context(player, target, null)))
	queue.run(self)
	return PlayResult.success()


func discard_potion(slot: int) -> bool:
	if slot < 0 or slot >= potions.size() or potions[slot] == null:
		return false
	var potion := potions[slot]
	potions[slot] = null
	emit(CombatEvent.Kind.POTION_DISCARDED, player, null, slot, potion.id)
	return true


func _check_turn() -> PlayResult:
	if is_over():
		return PlayResult.fail(PlayResult.COMBAT_OVER)
	if pending_choice != null:
		return PlayResult.fail(PlayResult.WAITING_FOR_CHOICE)
	if turn.phase != TurnState.Phase.PLAYER or not queue.is_empty():
		return PlayResult.fail(PlayResult.NOT_YOUR_TURN)
	# 協力プレイ：ターン終了を押した席・倒れた席はカードを出せない。
	if seat.ready or not seat.is_alive():
		return PlayResult.fail(PlayResult.NOT_YOUR_TURN)
	return PlayResult.success()


## いまの席のターン終了（協力プレイでは Ready）。全員が押したら敵のターンへ進む。
func end_turn() -> bool:
	if not _check_turn().ok:
		return false
	seat.ready = true
	_end_round_if_all_ready()
	return true


## 協力プレイ：ターン終了の取り消し（敵のターンが始まる前だけ）。
func cancel_ready() -> bool:
	if is_over() or turn.phase != TurnState.Phase.PLAYER or not seat.ready or not seat.is_alive():
		return false
	seat.ready = false
	emit(CombatEvent.Kind.READY_CHANGED, player, null, 0)
	return true


func all_ready() -> bool:
	for s in seats:
		if s.is_alive() and not s.ready:
			return false
	return true


func _end_round_if_all_ready() -> void:
	if not all_ready():
		emit(CombatEvent.Kind.READY_CHANGED, player, null, 1)
		return
	flow.end_player_turn()
	queue.run(self)


# —— 効果の解決 ——

func make_context(source: Combatant, chosen: Combatant, card: Card, x: int = 0, stats: ResolveStats = null) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.combat = self
	ctx.source = source
	ctx.chosen = chosen
	ctx.card = card
	ctx.x = x
	if stats != null:
		ctx.stats = stats
	return ctx


func make_preview_context(source: Combatant, chosen: Combatant, card: Card) -> EffectContext:
	var ctx := make_context(source, chosen, card, turn.energy)
	ctx.preview = true
	return ctx


func effect_actions(effects: Array[CardEffect], ctx: EffectContext) -> Array[CombatAction]:
	var actions: Array[CombatAction] = []
	if ctx.depth > EffectContext.MAX_DEPTH:
		push_error("Combat: effect nesting is too deep")
		return actions
	for e in effects:
		if e != null:
			actions.append(ResolveEffectAction.new(e, ctx))
	return actions


## 効果を「今すぐ続けて」実行するように積む。
func push_effects(effects: Array[CardEffect], ctx: EffectContext) -> void:
	queue.push_top_many(effect_actions(effects, ctx))


func defer(timing: DeferEffect.Timing, effects: Array[CardEffect], ctx: EffectContext) -> void:
	if not _deferred.has(timing):
		_deferred[timing] = []
	_deferred[timing].append([effects, ctx])


## 予約していた遅延効果をまとめて積む（積んだ順に実行される）。
func run_deferred(timing: DeferEffect.Timing) -> void:
	var list: Array = _deferred.get(timing, [])
	_deferred.erase(timing)
	var actions: Array[CombatAction] = []
	for entry: Array in list:
		actions.append_array(effect_actions(entry[0], entry[1]))
	queue.push_top_many(actions)


## カードのプレビュー（カードテキストの数値）。状態・乱数・イベントに一切触れない。
func preview_card(card: Card, target: Combatant = null) -> Preview:
	var p := Preview.new()
	var ctx := make_preview_context(player, target, card)
	for list: Array[CardEffect] in [card.data.on_play, card.data.on_draw, card.data.on_discard,
			card.data.on_exhaust, card.data.end_of_turn_in_hand]:
		for e in list:
			e.preview(ctx, p)
	return p


# —— カード選択（GameDesign §5.9）——

func request_choice(effect: ChooseCardsEffect, ctx: EffectContext) -> void:
	var choice := CardChoice.new()
	choice.source = effect.source
	choice.type_filter = effect.type_filter
	choice.exclude = ctx.card
	choice.action = effect.action
	choice.max_count = effect.count
	choice.min_count = 0 if effect.allow_fewer else effect.count
	choice.cancellable = effect.cancellable
	choice.prompt = effect.prompt
	choice.ctx = ctx
	queue.push_top(ChooseCardsAction.new(choice))


func refresh_choice_candidates(choice: CardChoice) -> void:
	choice.candidates.clear()
	for c in piles.pile(choice.source):
		if c != choice.exclude and c.matches(choice.type_filter):
			choice.candidates.append(c)
	choice.min_count = mini(choice.min_count, choice.candidates.size())


func waits_for_human(choice: CardChoice) -> bool:
	return interactive and turn.phase == TurnState.Phase.PLAYER and choice.ctx.source != null \
			and choice.ctx.source.is_player()


## 選択待ちの席（無ければ null）。
func choice_seat() -> PlayerSeat:
	if pending_choice == null or pending_choice.ctx == null:
		return null
	return seat_of(pending_choice.ctx.source)


## プレイヤーの回答。候補内のカードだけを受け付ける。受け付けたら解決を再開する。
func submit_choice(cards: Array[Card]) -> bool:
	var choice := pending_choice
	if choice == null or not choice.accepts(cards) or choice_seat() != seat:
		return false
	pending_choice = null
	resolve_choice(choice, cards)
	queue.run(self)
	return true


func resolve_choice(choice: CardChoice, cards: Array[Card]) -> void:
	for c in cards:
		match choice.action:
			ChooseCardsEffect.Action.DISCARD:
				if piles.hand.has(c):
					discard_from_hand(c)
				else:
					move_card(c, Pile.Place.DISCARD)
			ChooseCardsEffect.Action.EXHAUST:
				exhaust_card(c)
			ChooseCardsEffect.Action.RETAIN:
				c.retain_this_turn = true
				emit(CombatEvent.Kind.CARD_RETAINED, player, null, c.uid, c.data.id)
			ChooseCardsEffect.Action.DUPLICATE:
				var copy := create_cards(c.data, Pile.Place.HAND, 1, true, false)
				for made in copy:
					made.growth = c.growth
			ChooseCardsEffect.Action.TO_DRAW_TOP:
				move_card(c, Pile.Place.DRAW_TOP)
			ChooseCardsEffect.Action.TO_DRAW_BOTTOM:
				move_card(c, Pile.Place.DRAW_BOTTOM)
			ChooseCardsEffect.Action.TO_HAND:
				move_card(c, Pile.Place.HAND)
			ChooseCardsEffect.Action.TO_DISCARD:
				move_card(c, Pile.Place.DISCARD)
	choice.ctx.stats.cards_affected += cards.size()
	choice.resolved = true
	emit(CombatEvent.Kind.CHOICE_RESOLVED, player, null, cards.size())


# —— 敵 ——

func choose_intents() -> void:
	for e in alive_enemies():
		e.mind.current_move = e.data.ai.choose_move(e, self)
		emit(CombatEvent.Kind.INTENT_CHANGED, e, lead_player(), 0, e.mind.current_move.id if e.mind.current_move else &"")


## viewer = インテントの数字を見る側のプレイヤー（脆弱などで数字が変わる）。null なら今の席のプレイヤー。
func intent_of(enemy: Combatant, viewer: Combatant = null) -> Intent:
	var move := enemy.mind.current_move if enemy.mind != null else null
	if move == null or not enemy.is_alive():
		return Intent.new()
	var p := Preview.new()
	var ctx := make_preview_context(enemy, viewer if viewer != null else player, null)
	for e in move.effects:
		e.preview(ctx, p)
	return Intent.from_preview(move, p)


func _check_phase(enemy: Combatant) -> void:
	var next := enemy.data.ai.phase_after_damage(enemy)
	if next <= enemy.mind.phase:
		return
	enemy.mind.phase = next
	queue.push_bottom(CallAction.new(_enter_phase.bind(enemy, next)))


func _enter_phase(enemy: Combatant, phase: int) -> void:
	if not enemy.is_alive():
		return
	emit(CombatEvent.Kind.PHASE_CHANGED, enemy, enemy, phase)
	enemy.data.ai.on_phase_changed(enemy, self, phase)


# —— 死亡と終了 ——

func finalize_death(unit: Combatant) -> void:
	if unit.dead or unit.hp > 0:
		return
	unit.dead = true
	unit.block = 0
	emit(CombatEvent.Kind.UNIT_DIED, null, unit)
	hooks.notify(CombatBehavior.Hook.DEATH, unit)
	if unit.is_player():
		if alive_players().is_empty():
			end_combat(Outcome.DEFEAT)
		elif turn.phase == TurnState.Phase.PLAYER and all_ready():
			# 協力プレイ：残りの全員がターン終了を押していたら、倒れた人を待たずに敵のターンへ。
			flow.end_player_turn()
	elif alive_enemies().is_empty():
		end_combat(Outcome.VICTORY)


func end_combat(result: Outcome) -> void:
	if is_over():
		return
	outcome = result
	set_phase(TurnState.Phase.OVER)
	pending_choice = null
	queue.clear()
	_deferred.clear()
	if result == Outcome.VICTORY:
		hooks.notify(CombatBehavior.Hook.COMBAT_END, true)
	for s in seats:
		for card in s.piles.all_cards():
			card.reset_combat_mods()
	emit(CombatEvent.Kind.COMBAT_ENDED, null, null, 1 if result == Outcome.VICTORY else 0)


## 無限ループのガードなどで異常終了する。
func abort() -> void:
	end_combat(Outcome.ABORTED)


func result() -> CombatResult:
	return result_for(0)


## 席ごとの結果（協力プレイ）。
func result_for(index: int) -> CombatResult:
	var s := seats[index]
	var r := CombatResult.new()
	r.victory = outcome == Outcome.VICTORY
	r.aborted = outcome == Outcome.ABORTED
	r.hp = s.unit.hp
	r.max_hp = s.unit.max_hp
	r.gold_gained = s.gold_gained
	r.potions = s.potions.duplicate()
	r.turns = s.turn.number
	r.downed = not s.unit.is_alive()
	return r


# —— イベント ——

func emit(kind: CombatEvent.Kind, source: Combatant = null, target: Combatant = null, value: int = 0,
		id: StringName = &"", flags: int = 0, snapshot: Dictionary = {}) -> void:
	var e := CombatEvent.new()
	e.kind = kind
	e.source_uid = source.uid if source != null else -1
	e.target_uid = target.uid if target != null else -1
	e.value = value
	e.id = id
	e.flags = flags
	e.snapshot = snapshot
	events.append(e)
	version += 1
	event_emitted.emit(e)

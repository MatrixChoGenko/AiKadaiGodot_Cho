class_name RunController extends RefCounted
## ④ Flow：ラン進行のステートマシン（Architecture §10.2）。フローの遷移を行うのはここだけ（ルール 8）。
## 画面 / テスト / ボットはコマンド（enter_node、take_reward、buy …）を呼び、phase_changed で次の画面を知る。
## ノードの内容は種類ごとの NodeHandler（Strategy）が作る。
## セーブのチェックポイントは 4 か所（Architecture §10.3、ルール 10）。checkpoint_reached を誰も購読しなければ副作用はない。
## 協力プレイ（GameDesign §21）：プレイヤーごとのコマンドは最後の引数 player で誰の操作かを指定する（-1 = いまのプレイヤー）。
## マップは全員の投票（vote）、ノードを離れるのは全員が「進む」を押したとき（leave_node）。1 人プレイでは従来どおり即時。

signal phase_changed(phase: RunPhase.Id)
signal checkpoint_reached(reason: StringName)
## 戦闘を作った直後、開始（初手のドロー）の前に出る。購読者はここで event_emitted に接続すれば最初のイベントから受け取れる。
signal combat_started(combat: CombatController)
## 協力プレイ：投票・「進む」などの、フェーズは変わらないが他の人に見せたい変化。
signal party_changed

## 戦闘以外のノードに入ったとき：ノード確定後、内容の生成前。
const CP_NODE_ENTERED: StringName = &"node_entered"
## 開戦：シャッフルして初手を引く前。
const CP_COMBAT_STARTED: StringName = &"combat_started"
## 戦闘報酬の生成後。
const CP_REWARD_GENERATED: StringName = &"reward_generated"
## leave_node（マップ / アクト移行へ）。マップに入るとき（ランの開始、アクト移行の後）も同じ理由で出す（付録 C の C36）。
const CP_RETURNED_TO_MAP: StringName = &"returned_to_map"

var state: RunState
var content: ContentLibrary
var config: RunConfig
## 戦闘中のみ。
var combat: CombatController

var _handlers: Dictionary[MapNode.Type, NodeHandler] = {
	MapNode.Type.BATTLE: BattleNode.new(),
	MapNode.Type.ELITE: EliteNode.new(),
	MapNode.Type.BOSS: BossNode.new(),
	MapNode.Type.EVENT: EventNode.new(),
	MapNode.Type.SHOP: ShopNode.new(),
	MapNode.Type.REST: RestNode.new(),
	MapNode.Type.TREASURE: TreasureNode.new(),
}


## config = null なら content.config を使う。
func _init(p_content: ContentLibrary, p_config: RunConfig = null) -> void:
	content = p_content
	config = p_config if p_config != null else p_content.config


## アクトを number の順に並べたもの。
static func acts_of(lib: ContentLibrary) -> Array[ActData]:
	var acts := lib.acts.duplicate()
	acts.sort_custom(func(a: ActData, b: ActData) -> bool: return a.number < b.number)
	return acts


# —— 開始 / 再開 ——

## names を 2 つ以上渡すと協力プレイ（その人数・その順番の席）。
func start_new(seed_value: int, interactive: bool = true, names: PackedStringArray = PackedStringArray()) -> void:
	state = RunState.new()
	state.seed_value = seed_value
	state.rng = RngStreams.new(seed_value)
	state.interactive = interactive
	state.set_player_count(maxi(names.size(), 1))
	for p in state.players:
		if p.index < names.size():
			p.name = names[p.index]
		p.max_hp = config.start_max_hp
		p.hp = config.start_max_hp
		p.gold = config.start_gold
		p.energy_per_turn = config.energy_per_turn
		p.draw_per_turn = config.draw_per_turn
		p.potions = PotionBelt.new(config.potion_slots)
		for data in config.starting_deck:
			p.deck.add(data)
		for relic in config.starting_relics:
			p.add_relic(relic)
	state.act_index = 0
	_begin_act()


## ロードした RunState から現場を再構築する（Architecture §12.4）。
## 戦闘 → active_encounter で戦闘をやり直す。ショップ / イベント / 休憩 / 宝箱 → handler.on_resume()。報酬 → そのまま表示。
func resume(saved: RunState) -> void:
	state = saved
	combat = null
	match state.phase:
		RunPhase.Id.COMBAT:
			start_combat(content.encounter(state.active_encounter), state.active_encounter_rewards, false)
		RunPhase.Id.SHOP, RunPhase.Id.EVENT, RunPhase.Id.REST, RunPhase.Id.TREASURE:
			var node := state.current_node()
			_handler(node).on_resume(self, node)
	phase_changed.emit(state.phase)


func abandon() -> void:
	_finish(false)


# —— クエリ ——

func act() -> ActData:
	var acts := acts_of(content)
	return acts[clampi(state.act_index, 0, acts.size() - 1)]


func act_count() -> int:
	return content.acts.size()


func is_last_act() -> bool:
	return state.act_index >= act_count() - 1


func is_over() -> bool:
	return state.phase in [RunPhase.Id.DEFEAT, RunPhase.Id.VICTORY]


func is_coop() -> bool:
	return state != null and state.is_coop()


## マップで次に選べるノード。
func choices() -> Array[MapNode]:
	return state.map.choices_from(state.node_id)


func loot() -> LootTable:
	return LootTable.new(content, config, state.rng)


## プレイヤーのデータ（-1 = いまのプレイヤー）。
func player(index: int = -1) -> PlayerState:
	if index >= 0 and index < state.players.size():
		return state.players[index]
	return state.player


# —— マップ ——

func enter_node(node_id: int) -> bool:
	if state.phase != RunPhase.Id.MAP:
		return false
	var node := state.map.node(node_id)
	if node == null or not choices().has(node):
		return false
	for p in state.players:
		p.vote = -1
		p.done = false
	state.node_id = node_id
	state.visited.append(node_id)
	var handler := _handler(node)
	if not node.is_combat():
		state.phase = handler.phase()
		_checkpoint(CP_NODE_ENTERED)
	handler.enter(self, node)
	phase_changed.emit(state.phase)
	return true


## 協力プレイ：進むノードに投票する（取り消し = -1）。全員が投票したら多い方へ。同数は乱数（coop ストリーム）。
## 1 人プレイなら enter_node と同じ。
func vote(node_id: int, who: int = -1) -> bool:
	if not is_coop():
		return enter_node(node_id)
	if state.phase != RunPhase.Id.MAP:
		return false
	var p := player(who)
	if node_id >= 0:
		var node := state.map.node(node_id)
		if node == null or not choices().has(node):
			return false
	p.vote = node_id
	var counts: Dictionary[int, int] = {}
	for q in state.players:
		if q.vote < 0:
			party_changed.emit()
			return true
		counts[q.vote] = counts.get(q.vote, 0) + 1
	var best := 0
	for id in counts:
		best = maxi(best, counts[id])
	var tied: Array[int] = []
	for id in counts:
		if counts[id] == best:
			tied.append(id)
	tied.sort()
	var chosen: int = tied[0] if tied.size() == 1 else tied[state.rng.range_int(&"coop", 0, tied.size() - 1)]
	return enter_node(chosen)


## マップへ戻る唯一の出口。予約された戦闘があれば戦闘へ、ボスのノードならアクト移行へ進む。
## 協力プレイでは、その人の「進む」を記録し、全員が押したときだけ進む。
func leave_node(who: int = -1) -> bool:
	if not can_leave(who):
		return false
	if is_coop():
		player(who).done = true
		if not _everyone_done():
			party_changed.emit()
			return true
	_leave()
	return true


func can_leave(who: int = -1) -> bool:
	if state == null:
		return false
	var p := player(who)
	match state.phase:
		RunPhase.Id.REWARD, RunPhase.Id.TREASURE, RunPhase.Id.SHOP:
			return true
		RunPhase.Id.EVENT:
			return p.event_choice >= 0 and p.pending_requests.is_empty()
		RunPhase.Id.REST:
			return p.rest_used
	return false


## 協力プレイ：「進む」の取り消し（全員が揃う前だけ）。
func cancel_leave(who: int = -1) -> bool:
	if not is_coop() or not player(who).done:
		return false
	player(who).done = false
	party_changed.emit()
	return true


func advance_act(who: int = -1) -> bool:
	if state.phase != RunPhase.Id.ACT_TRANSITION:
		return false
	if is_coop():
		player(who).done = true
		if not _everyone_done():
			party_changed.emit()
			return true
	state.act_index += 1
	for p in state.players:
		p.done = false
		p.change_hp(maxi(1, int(p.max_hp * config.act_heal_percent / 100.0)))
	_begin_act()
	return true


# —— 戦闘 ——

## 戦闘を始める（NodeHandler と leave_node から呼ぶ）。チェックポイントは初手のシャッフルの前。
func start_combat(encounter: EncounterData, rewards: bool, checkpoint: bool = true) -> void:
	assert(encounter != null, "RunController.start_combat: encounter is null")
	state.active_encounter = encounter.id
	state.active_encounter_rewards = rewards
	state.phase = RunPhase.Id.COMBAT
	if checkpoint:
		_checkpoint(CP_COMBAT_STARTED)
	combat = CombatController.from_combat(Combat.create(_combat_setup(encounter)))
	combat_started.emit(combat)
	combat.start()


## プレイヤーが戦闘終了画面で「続ける」を押した。結果を RunState に書き戻し、報酬 / 次のアクト / 勝敗へ進む。
## 協力プレイでは、倒れた人は勝利なら HP coop_revive_hp で復活する（GameDesign §21）。
func acknowledge_combat_end() -> bool:
	if state.phase != RunPhase.Id.COMBAT or combat == null or not combat.is_over():
		return false
	var victory := combat.result().victory
	for p in state.players:
		var r := combat.result_for(p.index)
		p.hp = r.hp
		p.max_hp = r.max_hp
		if r.downed and victory:
			p.hp = mini(maxi(config.coop_revive_hp, 1), p.max_hp)
		p.change_gold(r.gold_gained)
		p.potions.slots.assign(r.potions)
	combat = null
	var encounter := content.encounter(state.active_encounter)
	var rewards := state.active_encounter_rewards
	state.active_encounter = &""
	state.active_encounter_rewards = true
	if not victory:
		_finish(false)
		return true
	state.battles_won += 1
	var node := state.current_node()
	if node != null and node.type == MapNode.Type.BOSS and is_last_act():
		_finish(true)   # 最後のアクトのボスは報酬なしで勝利（付録 C の C28）
		return true
	if rewards:
		for p in state.players:
			p.pending_reward = RewardFactory.for_combat(loot(), encounter.rank, p.owned_relics())
		state.phase = RunPhase.Id.REWARD
		_checkpoint(CP_REWARD_GENERATED)
		phase_changed.emit(state.phase)
	else:
		_leave()
	return true


# —— 報酬 / 宝箱 ——

## 報酬の 1 行を受け取る。CARDS は card_index で 1 枚を選ぶ。ポーション枠がいっぱいなら false（後で受け取れる）。
func take_reward(item_index: int, card_index: int = -1, who: int = -1) -> bool:
	state.use_player(who)
	if state.phase not in [RunPhase.Id.REWARD, RunPhase.Id.TREASURE] or state.pending_reward == null:
		return false
	var item := state.pending_reward.item(item_index)
	if item == null or item.taken:
		return false
	match item.kind:
		RewardItem.Kind.GOLD:
			state.change_gold(item.gold)
		RewardItem.Kind.CARDS:
			if card_index < 0 or card_index >= item.cards.size():
				return false
			state.deck.add(item.cards[card_index])
		RewardItem.Kind.RELIC:
			state.add_relic(item.relic)
		RewardItem.Kind.POTION:
			if not state.potions.add(item.potion):
				return false
	item.taken = true
	return true


## ラン中の画面でポーションを捨てる（戦闘中は CombatController.discard_potion を使う）。
func discard_potion(slot: int, who: int = -1) -> bool:
	if state.phase == RunPhase.Id.COMBAT or is_over():
		return false
	return player(who).potions.remove(slot) != null


# —— ショップ ——

func can_buy(item_index: int, who: int = -1) -> bool:
	var p := player(who)
	if state.phase != RunPhase.Id.SHOP or p.shop == null:
		return false
	var item := p.shop.item(item_index)
	if item == null or item.sold or p.gold < item.price:
		return false
	return item.kind != ShopItem.Kind.POTION or not p.potions.is_full()


func buy(item_index: int, who: int = -1) -> bool:
	state.use_player(who)
	if not can_buy(item_index):
		return false
	var item := state.shop.item(item_index)
	match item.kind:
		ShopItem.Kind.CARD:
			state.deck.add(item.card)
		ShopItem.Kind.RELIC:
			state.add_relic(item.relic)
		ShopItem.Kind.POTION:
			state.potions.add(item.potion)
	state.change_gold(-item.price)
	item.sold = true
	return true


func removal_price(who: int = -1) -> int:
	return ShopFactory.removal_price(config, player(who).removals_bought)


func upgrade_price(who: int = -1) -> int:
	return ShopFactory.upgrade_price(config, player(who).upgrades_bought)


## カード削除サービス。1 回の訪問で何度でも使え、使うたびに値上がりする（付録 C の C27）。
func buy_removal(card: Card, who: int = -1) -> bool:
	state.use_player(who)
	if state.phase != RunPhase.Id.SHOP or state.gold < removal_price() or not state.deck.has(card):
		return false
	state.change_gold(-removal_price())
	state.deck.remove(card)
	state.removals_bought += 1
	return true


func buy_upgrade(card: Card, who: int = -1) -> bool:
	state.use_player(who)
	if state.phase != RunPhase.Id.SHOP or state.gold < upgrade_price() or not state.deck.has(card) or not card.can_upgrade():
		return false
	state.change_gold(-upgrade_price())
	card.upgrade()
	state.upgrades_bought += 1
	return true


# —— イベント ——

func event_option_available(index: int, who: int = -1) -> bool:
	if state.phase != RunPhase.Id.EVENT or state.event == null:
		return false
	if index < 0 or index >= state.event.options.size():
		return false
	# クエリなので、いまのプレイヤーを一時的に切り替えて戻す（表現層から何度呼ばれても状態を変えない）。
	var before := state.active
	state.use_player(who)
	var ok := _effect_context().test(state.event.options[index].requires)
	state.active = before
	return ok


## 選択肢を選ぶ（1 人 1 回だけ）。効果をその人に実行し、カード選択のリクエストを積む。選べなければ null。
## 協力プレイでも各自が自分の選択肢を選ぶ。戦闘を予約する選択肢は誰が選んでも全員の戦闘になる（GameDesign §21）。
func choose_event_option(index: int, who: int = -1) -> EventOutcome:
	state.use_player(who)
	if state.event_choice >= 0 or not event_option_available(index):
		return null
	var option := state.event.options[index]
	var ctx := _effect_context()
	ctx.apply_all(option.effects)
	state.event_choice = index
	state.pending_requests.append_array(ctx.requests)
	_drop_empty_requests()
	var outcome := EventOutcome.new()
	outcome.result_text = option.result_text
	outcome.request_count = state.pending_requests.size()
	outcome.battle_queued = state.queued_encounter != &""
	return outcome


## 処理待ちの先頭のカード選択リクエスト。無ければ null。
func pending_request(who: int = -1) -> RunChoiceRequest:
	var p := player(who)
	return p.pending_requests[0] if not p.pending_requests.is_empty() else null


## 先頭のリクエストの候補。REMOVE / UPGRADE は Card、PICK は CardData。
func request_candidates(who: int = -1) -> Array:
	var req := pending_request(who)
	if req == null:
		return []
	var p := player(who)
	match req.kind:
		RunChoiceRequest.Kind.REMOVE:
			return p.deck.cards.duplicate()
		RunChoiceRequest.Kind.UPGRADE:
			return p.deck.upgradable()
		_:
			return req.offers.duplicate()


## 先頭のリクエストで選ぶべき枚数（候補が少なければ候補の数。キャンセル不可）。
func request_pick_count(who: int = -1) -> int:
	var req := pending_request(who)
	if req == null:
		return 0
	var n := request_candidates(who).size()
	return mini(1, n) if req.kind == RunChoiceRequest.Kind.PICK else mini(req.count, n)


## 先頭のリクエストに答える。indices は request_candidates() の添字で、ちょうど request_pick_count() 個。
func resolve_request(indices: PackedInt32Array, who: int = -1) -> bool:
	state.use_player(who)
	var req := pending_request()
	if req == null:
		return false
	var candidates := request_candidates()
	if indices.size() != request_pick_count():
		return false
	var seen: Dictionary[int, bool] = {}
	for i in indices:
		if i < 0 or i >= candidates.size() or seen.has(i):
			return false
		seen[i] = true
	for i in indices:
		match req.kind:
			RunChoiceRequest.Kind.REMOVE:
				state.deck.remove(candidates[i] as Card)
			RunChoiceRequest.Kind.UPGRADE:
				(candidates[i] as Card).upgrade()
			RunChoiceRequest.Kind.PICK:
				state.deck.add(candidates[i] as CardData)
	state.pending_requests.pop_front()
	_drop_empty_requests()
	return true


# —— 休憩 ——

func rest_heal(who: int = -1) -> bool:
	state.use_player(who)
	if state.phase != RunPhase.Id.REST or state.rest_used:
		return false
	state.change_hp(int(state.max_hp * config.rest_heal_percent / 100.0))
	state.rest_used = true
	return true


func can_rest_upgrade(who: int = -1) -> bool:
	var p := player(who)
	return state.phase == RunPhase.Id.REST and not p.rest_used and not p.deck.upgradable().is_empty()


func rest_upgrade(card: Card, who: int = -1) -> bool:
	state.use_player(who)
	if not can_rest_upgrade() or not state.deck.has(card) or not card.can_upgrade():
		return false
	card.upgrade()
	state.rest_used = true
	return true


# —— 内部 ——

func _everyone_done() -> bool:
	for p in state.players:
		if not p.done:
			return false
	return true


func _begin_act() -> void:
	state.map = MapGenerator.generate(state.rng, act(), content, config)
	state.node_id = -1
	state.visited = PackedInt32Array()
	_enter_map()


func _enter_map() -> void:
	state.clear_node_state()
	for p in state.players:
		p.vote = -1
	state.phase = RunPhase.Id.MAP
	_checkpoint(CP_RETURNED_TO_MAP)
	phase_changed.emit(state.phase)


func _leave() -> void:
	var node := state.current_node()
	state.clear_node_state()
	if state.queued_encounter != &"":
		var encounter := content.encounter(state.queued_encounter)
		var rewards := state.queued_encounter_rewards
		state.queued_encounter = &""
		state.queued_encounter_rewards = true
		if encounter != null:
			start_combat(encounter, rewards)
			phase_changed.emit(state.phase)
			return
	if node != null and node.type == MapNode.Type.BOSS:
		state.phase = RunPhase.Id.ACT_TRANSITION
		_checkpoint(CP_RETURNED_TO_MAP)
		phase_changed.emit(state.phase)
		return
	_enter_map()


func _finish(victory: bool) -> void:
	combat = null
	state.clear_node_state()
	state.phase = RunPhase.Id.VICTORY if victory else RunPhase.Id.DEFEAT
	phase_changed.emit(state.phase)


func _checkpoint(reason: StringName) -> void:
	checkpoint_reached.emit(reason)


func _handler(node: MapNode) -> NodeHandler:
	return _handlers[node.type]


func _effect_context() -> RunEffectContext:
	return RunEffectContext.new(state, content, config, act().number)


## 候補が 0 のリクエスト（削除するカードが無いなど）は飛ばす。
func _drop_empty_requests() -> void:
	while pending_request() != null and request_pick_count() == 0:
		state.pending_requests.pop_front()


func _combat_setup(encounter: EncounterData) -> CombatSetup:
	var setup := CombatSetup.new()
	setup.encounter = encounter
	setup.config = config
	setup.rng = state.rng
	setup.interactive = state.interactive
	var p0 := state.players[0]
	setup.player_name = p0.name
	setup.player_hp = p0.hp
	setup.player_max_hp = p0.max_hp
	setup.energy_per_turn = p0.energy_per_turn
	setup.draw_per_turn = p0.draw_per_turn
	setup.deck = p0.deck.cards.duplicate()
	setup.relics = p0.relics
	setup.potions = p0.potions.slots.duplicate()
	if state.is_coop():
		for p in state.players:
			var ss := CombatSeatSetup.new()
			ss.name = p.name
			ss.hp = p.hp
			ss.max_hp = p.max_hp
			ss.energy_per_turn = p.energy_per_turn
			ss.draw_per_turn = p.draw_per_turn
			ss.deck = p.deck.cards.duplicate()
			ss.relics = p.relics
			ss.potions = p.potions.slots.duplicate()
			setup.seats.append(ss)
	return setup

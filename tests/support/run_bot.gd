class_name RunBot extends RefCounted
## テスト支援：RunController を合法な操作でランダムに進めるボット（Architecture §18.3 の自動ラン）。
## 戦闘は RandomBot に任せる。ボットの乱数はこの rng 1 本だけなので、チェックポイントで rng.state を記録しておけば
## セーブ → ロードの後に同じ判断を再現できる（中断しなかった場合との一致の検査に使う）。

const MAX_STEPS: int = 3000

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stats: Dictionary = {
	combats = 0, rewards_taken = 0, shop_buys = 0, removals = 0, upgrades = 0,
	events = 0, requests = 0, rests = 0, rest_upgrades = 0, treasures = 0, act_transitions = 0,
}
## 失敗の説明（hung のとき）。
var failure: String = ""


func _init(seed_value: int) -> void:
	rng.seed = seed_value


## ランが終わるまで進める。戻り値：{ steps, hung }。
func play(run: RunController, max_steps: int = MAX_STEPS) -> Dictionary:
	var steps := 0
	while not run.is_over():
		steps += 1
		if steps > max_steps:
			failure = "step limit"
			return {steps = steps, hung = true}
		if not step(run):
			return {steps = steps, hung = true}
	return {steps = steps, hung = false}


## 1 つのフェーズを処理して次のフェーズへ進める。進められなければ false。
func step(run: RunController) -> bool:
	match run.state.phase:
		RunPhase.Id.MAP:
			var choices := run.choices()
			if choices.is_empty():
				return _fail("no map choices")
			return run.enter_node(choices[rng.randi_range(0, choices.size() - 1)].id) or _fail("enter_node rejected")
		RunPhase.Id.COMBAT:
			stats.combats += 1
			var outcome := RandomBot.new(rng.randi()).play(run.combat)
			if outcome["hung"]:
				return _fail("combat hung")
			return run.acknowledge_combat_end() or _fail("acknowledge rejected")
		RunPhase.Id.REWARD, RunPhase.Id.TREASURE:
			if run.state.phase == RunPhase.Id.TREASURE:
				stats.treasures += 1
			_take_rewards(run)
			return run.leave_node() or _fail("leave reward rejected")
		RunPhase.Id.SHOP:
			_shop(run)
			return run.leave_node() or _fail("leave shop rejected")
		RunPhase.Id.EVENT:
			return _event(run)
		RunPhase.Id.REST:
			stats.rests += 1
			var upgradable := run.state.deck.upgradable()
			if run.can_rest_upgrade() and rng.randi_range(0, 1) == 0:
				stats.rest_upgrades += 1
				if not run.rest_upgrade(upgradable[rng.randi_range(0, upgradable.size() - 1)]):
					return _fail("rest_upgrade rejected")
			elif not run.rest_heal():
				return _fail("rest_heal rejected")
			return run.leave_node() or _fail("leave rest rejected")
		RunPhase.Id.ACT_TRANSITION:
			stats.act_transitions += 1
			return run.advance_act() or _fail("advance_act rejected")
	return _fail("unexpected phase %s" % RunPhase.Id.keys()[run.state.phase])


func _take_rewards(run: RunController) -> void:
	var reward := run.state.pending_reward
	for i in reward.items.size():
		var item := reward.items[i]
		match item.kind:
			RewardItem.Kind.CARDS:
				if rng.randi_range(0, 9) < 7 and run.take_reward(i, rng.randi_range(0, item.cards.size() - 1)):
					stats.rewards_taken += 1
			RewardItem.Kind.POTION:
				if run.state.potions.is_full() and rng.randi_range(0, 1) == 0:
					run.discard_potion(rng.randi_range(0, run.state.potions.slots.size() - 1))
				if run.take_reward(i):
					stats.rewards_taken += 1
			_:
				if run.take_reward(i):
					stats.rewards_taken += 1


func _shop(run: RunController) -> void:
	for attempt in rng.randi_range(0, 5):
		var roll := rng.randi_range(0, 9)
		if roll < 7:
			var i := rng.randi_range(0, run.state.shop.items.size() - 1)
			if run.buy(i):
				stats.shop_buys += 1
		elif roll < 9:
			if not run.state.deck.cards.is_empty():
				var card := run.state.deck.cards[rng.randi_range(0, run.state.deck.size() - 1)]
				if run.buy_removal(card):
					stats.removals += 1
		else:
			var upgradable := run.state.deck.upgradable()
			if not upgradable.is_empty() and run.buy_upgrade(upgradable[rng.randi_range(0, upgradable.size() - 1)]):
				stats.upgrades += 1


func _event(run: RunController) -> bool:
	if run.state.event_choice < 0:
		var available: Array[int] = []
		for i in run.state.event.options.size():
			if run.event_option_available(i):
				available.append(i)
		if available.is_empty():
			return _fail("event %s has no available option" % run.state.event.id)
		if run.choose_event_option(available[rng.randi_range(0, available.size() - 1)]) == null:
			return _fail("choose_event_option rejected")
		stats.events += 1
	while run.pending_request() != null:
		var n := run.request_candidates().size()
		var pool: Array[int] = []
		for i in n:
			pool.append(i)
		var picks := PackedInt32Array()
		for k in run.request_pick_count():
			picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		if not run.resolve_request(picks):
			return _fail("resolve_request rejected")
		stats.requests += 1
	return run.leave_node() or _fail("leave event rejected")


func _fail(message: String) -> bool:
	failure = message
	push_error("RunBot: " + message)
	return false

class_name UiBot extends RefCounted
## テスト支援：画面（Main + 各 Screen + モーダル）をクリックと同じ経路でランダムに操作して、ランを最後まで進めるボット。
## M4 の受け入れ（メインメニューから 1 ランを最後まで遊び、メインメニューに戻るまでエラーが出ない）をヘッドレスで検査する。
## 戦闘の再生は presenter.instant で待たずに進める。マウスのドラッグそのものは通らない（HandInput の先の try_play を呼ぶ）。
## 協力プレイ（GameDesign §21）でも使える：自分（Party.me / CombatScreen.me）の持ち物を見て操作し、操作の返事（ホスト経由）が
## 来るまでや、投票・「進む」を押した後のほかの人の待ちでは何もしない。

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stats: Dictionary = {
	combats = 0, cards_played = 0, potions_used = 0, choices = 0, rewards = 0, shop_buys = 0,
	events = 0, requests = 0, rests = 0, act_transitions = 0, outcome = "",
}
var failure: String = ""

var _main: Node
var _last_screen: Screen
var _screen_steps: int = 0
var _opened_cards: Dictionary[int, bool] = {}


func _init(main: Node, seed_value: int) -> void:
	_main = main
	rng.seed = seed_value


## 現在のランが終わってメインメニューに戻るまで操作する。戻り値 true = 完走。
func play(tree: SceneTree, max_frames: int = 60000) -> bool:
	for frame in max_frames:
		if not step():
			return failure.is_empty()
		await tree.process_frame
	failure = "frame limit (screen %s)" % _main.call(&"current_screen")
	return false


## 1 フレーム分の操作。ランが終わってメインメニューに戻ったら false。
func step() -> bool:
	var modals := _main.get_node("%ModalHost") as ModalHost
	var screen := _main.call(&"current_screen") as Screen
	if screen != _last_screen:
		_last_screen = screen
		_screen_steps = 0
		_opened_cards.clear()
	_screen_steps += 1
	if _screen_steps > 4000:
		failure = "stuck on %s" % screen
		return false
	if not modals.is_empty():
		_answer_modal(modals.top())
		return true
	if screen is MainMenuScreen:
		return stats.outcome == ""
	if screen is LobbyScreen:
		# 協力プレイ：ランの後（または相手が先にメニューへ戻って切れた後）はロビーに戻る。
		if stats.outcome == "":
			failure = "lobby: %s" % (screen as LobbyScreen).message
		return false
	if screen is MapScreen:
		var map_run := _main.get(&"run") as RunController
		if Party.coop() and Party.me(map_run).vote >= 0:
			return true   # ほかの人の投票を待つ
		var choices := map_run.choices()
		if choices.is_empty() or not (screen as MapScreen).choose_node(choices[rng.randi_range(0, choices.size() - 1)].id):
			failure = "map: cannot choose a node"
		return failure.is_empty()
	if screen is CombatScreen:
		_combat(screen as CombatScreen)
	elif screen is RewardScreen:
		_reward(screen as RewardScreen)
	elif screen is ShopScreen:
		_shop(screen as ShopScreen)
	elif screen is EventScreen:
		_event(screen as EventScreen)
	elif screen is RestScreen:
		var rest := screen as RestScreen
		if _waiting_for_party(rest.run):
			return true
		if Party.me(rest.run).rest_used:
			rest.leave()
		elif rest.run.can_rest_upgrade(Party.seat()) and rng.randi_range(0, 1) == 0:
			rest.open_upgrade()
		else:
			stats.rests += 1
			rest.rest()
	elif screen is ActTransitionScreen:
		if _waiting_for_party(screen.run):
			return true
		stats.act_transitions += 1
		(screen as ActTransitionScreen).advance()
	elif screen is RunEndScreen:
		stats.outcome = "victory" if screen.run.state.phase == RunPhase.Id.VICTORY else "defeat"
		screen.main_menu_requested.emit()
	return failure.is_empty()


## 協力プレイで「進む」を押してほかの人を待っている（押し直すと取り消しになるので何もしない）。
func _waiting_for_party(run: RunController) -> bool:
	return Party.coop() and Party.me(run).done


func _answer_modal(modal: Modal) -> void:
	var list := modal as CardListModal
	if list == null or list.max_count <= 0:
		modal.cancel()
		if not modal.cancellable:
			modal.close()
		return
	# アップグレードの比較（クリック → 比較 → 決定 / 戻る）も通す。
	if list.comparing >= 0:
		if rng.randi_range(0, 3) == 0:
			list.close_compare()
		else:
			stats.choices += 1
			list.confirm_compare()
		return
	if list.upgrade_preview and rng.randi_range(0, 1) == 0:
		list.open_compare(rng.randi_range(0, list.card_count() - 1))
		return
	var n := list.card_count()
	var count := rng.randi_range(list.min_count, mini(list.max_count, n))
	if list.cancellable and rng.randi_range(0, 9) == 0:
		modal.cancel()
		return
	var pool: Array[int] = []
	for i in n:
		pool.append(i)
	var picked := PackedInt32Array()
	for i in count:
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	stats.choices += 1
	if not list.choose(picked):
		failure = "modal rejected a valid choice"


func _combat(screen: CombatScreen) -> void:
	screen.presenter.instant = true
	if screen.result_pending():
		stats.combats += 1
		screen.continue_after_result()
		return
	if not screen.can_act():
		return
	var ctl := screen.ctl
	var me := screen.me()
	var options: Array = []
	var targets: Array = [null]
	targets.append_array(ctl.combat.alive_enemies())
	for card in me.piles.hand:
		for t: Variant in targets:
			if ctl.check_card(card, t, screen.my_index).ok:
				options.append(["card", card, t])
	for slot in me.potions.size():
		for t: Variant in targets:
			if ctl.check_potion(slot, t, screen.my_index).ok and rng.randi_range(0, 99) < 20:
				options.append(["potion", slot, t])
	if options.is_empty() or rng.randi_range(0, 99) < 10:
		screen.end_turn()
		return
	var pick: Array = options[rng.randi_range(0, options.size() - 1)]
	var ok: bool
	if pick[0] == "card":
		ok = screen.try_play(pick[1], pick[2])
		stats.cards_played += 1
	else:
		ok = screen.try_use_potion(pick[1], pick[2])
		stats.potions_used += 1
	if not ok:
		failure = "combat: a legal option was rejected"


func _reward(screen: RewardScreen) -> void:
	if _waiting_for_party(screen.run):
		return
	var reward := Party.me(screen.run).pending_reward
	if reward != null:
		for i in reward.items.size():
			var item := reward.items[i]
			if item.taken:
				continue
			if item.kind == RewardItem.Kind.CARDS:
				if _opened_cards.has(i):
					continue
				_opened_cards[i] = true
			elif item.kind == RewardItem.Kind.POTION and Party.me(screen.run).potions.is_full():
				continue
			stats.rewards += 1
			screen.take(i)
			return
	screen.leave()


func _shop(screen: ShopScreen) -> void:
	var run := screen.run
	if _waiting_for_party(run):
		return
	var me := Party.me(run)
	var who := Party.seat()
	if _screen_steps < 4 and rng.randi_range(0, 1) == 0:
		var buyable: Array[int] = []
		for i in me.shop.items.size():
			if run.can_buy(i, who):
				buyable.append(i)
		if not buyable.is_empty():
			stats.shop_buys += 1
			screen.buy(buyable[rng.randi_range(0, buyable.size() - 1)])
			return
		if me.gold >= run.upgrade_price(who) and not me.deck.upgradable().is_empty() and rng.randi_range(0, 1) == 0:
			stats.shop_buys += 1
			screen.open_upgrade()
			return
		if me.gold >= run.removal_price(who):
			stats.shop_buys += 1
			screen.open_removal()
			return
	screen.leave()


func _event(screen: EventScreen) -> void:
	var run := screen.run
	if _waiting_for_party(run):
		return
	var who := Party.seat()
	if Party.me(run).event_choice < 0:
		var available: Array[int] = []
		for i in run.state.event.options.size():
			if run.event_option_available(i, who):
				available.append(i)
		if available.is_empty():
			failure = "event: no option available"
			return
		stats.events += 1
		screen.choose(available[rng.randi_range(0, available.size() - 1)])
	elif run.pending_request(who) != null:
		stats.requests += 1
		screen.open_request()
	else:
		screen.leave()

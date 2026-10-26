class_name RandomBot extends RefCounted
## テスト支援：合法な操作をランダムに選び続けるボット（Architecture §18.3 のシミュレーション）。
## クラッシュ（エンジンのエラー）とハング（操作の上限・ActionQueue のガード）を検出するのに使う。

const MAX_ACTIONS: int = 4000

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 操作のたびに呼ばれる（不変条件の検査用）。引数なし。
var on_idle: Callable = Callable()


func _init(seed_value: int) -> void:
	rng.seed = seed_value


## 戦闘が終わるまで操作する。戻り値：{ actions, hung }。
func play(ctl: CombatController) -> Dictionary:
	var actions := 0
	while not ctl.is_over():
		actions += 1
		if actions > MAX_ACTIONS:
			return {actions = actions, hung = true}
		if on_idle.is_valid():
			on_idle.call()
		var choice := ctl.pending_choice()
		if choice != null:
			_answer(ctl, choice)
			continue
		var options := _options(ctl)
		if options.is_empty() or rng.randi_range(0, 99) < 12:
			if not ctl.end_turn():
				return {actions = actions, hung = true}   # 終了も操作もできない = 詰まり
			continue
		var pick: Array = options[rng.randi_range(0, options.size() - 1)]
		var r: PlayResult
		if pick[0] == "card":
			r = ctl.play_card(pick[1], pick[2])
		else:
			r = ctl.use_potion(pick[1], pick[2])
		if not r.ok:
			push_error("RandomBot: a legal option was rejected: %s" % r.reason)
			return {actions = actions, hung = true}
	return {actions = actions, hung = false}


func _answer(ctl: CombatController, choice: CardChoice) -> void:
	var pool := choice.candidates.duplicate()
	var n := rng.randi_range(choice.min_count, mini(choice.max_count, pool.size()))
	var picked: Array[Card] = []
	for i in n:
		var idx := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[idx])
		pool.remove_at(idx)
	if not ctl.submit_choice(picked):
		push_error("RandomBot: a valid choice was rejected")


## [種類, カード or 枠, 対象] の一覧。
func _options(ctl: CombatController) -> Array:
	var combat := ctl.combat
	var options: Array = []
	var targets: Array = [null]
	targets.append_array(combat.alive_enemies())
	for card in combat.piles.hand:
		for t: Variant in targets:
			if ctl.check_card(card, t).ok:
				options.append(["card", card, t])
	for slot in combat.potions.size():
		for t: Variant in targets:
			if ctl.check_potion(slot, t).ok and rng.randi_range(0, 99) < 30:
				options.append(["potion", slot, t])
	return options

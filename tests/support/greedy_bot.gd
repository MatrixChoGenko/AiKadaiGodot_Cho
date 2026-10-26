class_name GreedyBot extends RefCounted
## テスト支援：バランス測定用の「そこそこ上手い」ボット（RandomBot と違い、勝ちを目指して打つ）。
## 1 手ずつ、カードのプレビュー（与えるダメージ・得るブロック）と敵のインテント（受けるダメージ）から
## 「エネルギー 1 あたりの価値」が最大の手を選ぶ。先読みはしないので、人間の上手い人よりは少し下手。
##   - ダメージ：実際に削れる量（ブロックと残り HP で頭打ち）。倒せるなら、その敵の今ターンの攻撃も防げた分を足す。
##   - ブロック：受けるダメージのうち、まだ防げていない分まで。超えた分は価値なし。
##   - デバフ：敵に付けるなら少しだけ加点（脆弱・弱体を先に入れる）。
##   - 状態異常・呪いなど何もしないカード：エネルギーが余ったときだけ使う（手札から消す）。
## ポーションは使わない。カード選択は先頭から必要数だけ選ぶ。

const MAX_ACTIONS: int = 4000
const BLOCK_WEIGHT: float = 1.15
const DEBUFF_BONUS: float = 4.0
const FILLER_VALUE: float = 0.05


## 戦闘が終わるまで操作する。戻り値：{ actions, hung }。
func play(ctl: CombatController) -> Dictionary:
	var actions := 0
	while not ctl.is_over():
		actions += 1
		if actions > MAX_ACTIONS:
			return {actions = actions, hung = true}
		var choice := ctl.pending_choice()
		if choice != null:
			var picked: Array[Card] = []
			for i in mini(choice.min_count, choice.candidates.size()):
				picked.append(choice.candidates[i])
			if not ctl.submit_choice(picked):
				return {actions = actions, hung = true}
			continue
		var best := _best_play(ctl)
		if best.is_empty():
			if not ctl.end_turn():
				return {actions = actions, hung = true}
			continue
		var r := ctl.play_card(best[0], best[1])
		if not r.ok:
			push_error("GreedyBot: a legal option was rejected: %s" % r.reason)
			return {actions = actions, hung = true}
	return {actions = actions, hung = false}


## [カード, 対象]。打つ価値のある手が無ければ空。
func _best_play(ctl: CombatController) -> Array:
	var combat := ctl.combat
	var enemies := combat.alive_enemies()
	var incoming := 0
	for e in enemies:
		incoming += _incoming_from(ctl, e)
	var need := maxi(incoming - combat.player.block, 0)
	var targets: Array = [null]
	targets.append_array(enemies)
	var best: Array = []
	var best_score := 0.0
	for card in combat.piles.hand:
		for t: Variant in targets:
			if not ctl.check_card(card, t).ok:
				continue
			var p := combat.preview_card(card, t)
			var value := _value(ctl, p, t, need)
			if value <= 0.0:
				continue
			var score := value / maxf(ctl.cost_of(card), 0.5)
			if score > best_score:
				best_score = score
				best = [card, t]
	return best


func _value(ctl: CombatController, p: Preview, target: Variant, need: int) -> float:
	var value := 0.0
	if target != null:
		var t := target as Combatant
		var dmg := p.attack_damage * p.attack_hits
		var through := maxi(dmg - t.block, 0)
		value += mini(through, t.hp)
		if through >= t.hp:
			value += _incoming_from(ctl, t) * BLOCK_WEIGHT
		if p.debuffs:
			value += DEBUFF_BONUS
	value += mini(p.block, need) * BLOCK_WEIGHT
	if value <= 0.0:
		value = FILLER_VALUE
	return value


func _incoming_from(ctl: CombatController, enemy: Combatant) -> int:
	var intent := ctl.intent_of(enemy)
	return intent.total_damage() if intent != null and intent.is_attack() else 0

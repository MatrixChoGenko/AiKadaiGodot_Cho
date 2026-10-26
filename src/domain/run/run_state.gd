class_name RunState extends RefCounted
## ③ Domain：ラン中の可変データのすべて（Architecture §10.1）。セーブの唯一の出所。
## データと単純な不変条件（HP の範囲など）だけを置き、フローの判断（次にどのフェーズへ行くか）は RunController が行う。
## 協力プレイ（GameDesign §21）：プレイヤーごとのデータは players（PlayerState）にあり、マップ・乱数・フェーズは共有。
## 下の hp / gold / deck などは「いま処理しているプレイヤー」（active）のものを指す。RunController がコマンドごとに
## active を切り替えるので、イベントの効果（RunEffect）は誰のための処理かを意識しない。表現層は players を直接読む。

var seed_value: int = 0
var rng: RngStreams
var players: Array[PlayerState] = [PlayerState.new(0)]
## いま処理しているプレイヤーの番号（セーブしない）。
var active: int = 0
## 0 始まり。ContentLibrary.acts を number 順に並べたときの添字。
var act_index: int = 0
var map: MapGraph
## 現在のノード。-1 = アクトの開始時（まだどこにもいない）。
var node_id: int = -1
var visited: PackedInt32Array = PackedInt32Array()
var phase: RunPhase.Id = RunPhase.Id.MAP
var battles_won: int = 0
## イベントが予約した戦闘（leave_node が消費する）。
var queued_encounter: StringName = &""
var queued_encounter_rewards: bool = true
## 進行中の戦闘（ロード時はこれで戦闘をやり直す）。
var active_encounter: StringName = &""
var active_encounter_rewards: bool = true
## 人間がプレイ中か（戦闘中のカード選択で一時停止するかを決める）。セーブしない。
var interactive: bool = true

# —— ノードの中だけの共有の状態（セーブしない。ノードに入った時点のチェックポイントから再実行すれば同じになる） ——
var event: EventData

# —— いまのプレイヤー（active）のデータ ——
var player: PlayerState:
	get:
		return players[active]
var hp: int:
	get:
		return player.hp
	set(value):
		player.hp = value
var max_hp: int:
	get:
		return player.max_hp
	set(value):
		player.max_hp = value
var gold: int:
	get:
		return player.gold
	set(value):
		player.gold = value
var energy_per_turn: int:
	get:
		return player.energy_per_turn
	set(value):
		player.energy_per_turn = value
var draw_per_turn: int:
	get:
		return player.draw_per_turn
	set(value):
		player.draw_per_turn = value
var deck: Deck:
	get:
		return player.deck
	set(value):
		player.deck = value
## 順序 = 発動順。カウンタは RelicSlot.counter（セーブ対象）。
var relics: Array[RelicSlot]:
	get:
		return player.relics
var potions: PotionBelt:
	get:
		return player.potions
	set(value):
		player.potions = value
var removals_bought: int:
	get:
		return player.removals_bought
	set(value):
		player.removals_bought = value
var upgrades_bought: int:
	get:
		return player.upgrades_bought
	set(value):
		player.upgrades_bought = value
## 生成済みで受け取り待ちの報酬（REWARD / TREASURE）。
var pending_reward: Reward:
	get:
		return player.pending_reward
	set(value):
		player.pending_reward = value
var shop: ShopStock:
	get:
		return player.shop
	set(value):
		player.shop = value
## 選んだイベントの選択肢（-1 = まだ選んでいない）。
var event_choice: int:
	get:
		return player.event_choice
	set(value):
		player.event_choice = value
## イベントの効果が出したカード選択のリクエスト（先頭から 1 つずつ処理する）。
var pending_requests: Array[RunChoiceRequest]:
	get:
		return player.pending_requests
var rest_used: bool:
	get:
		return player.rest_used
	set(value):
		player.rest_used = value


func is_coop() -> bool:
	return players.size() > 1


## 協力プレイの人数分のプレイヤーを作り直す（ランの開始時だけ）。
func set_player_count(n: int) -> void:
	players.clear()
	for i in maxi(n, 1):
		players.append(PlayerState.new(i))
	active = 0


## 処理するプレイヤーを切り替える。範囲外なら変えない。
func use_player(index: int) -> void:
	if index >= 0 and index < players.size():
		active = index


## HP を変える（0〜最大 HP）。実際に変わった量を返す。
func change_hp(delta: int) -> int:
	return player.change_hp(delta)


## HP を減らすが 1 未満にはしない（イベントの HP 減少。GameDesign §7.5）。
func lose_hp_nonlethal(amount: int) -> int:
	return player.lose_hp_nonlethal(amount)


func change_max_hp(delta: int) -> void:
	player.change_max_hp(delta)


func change_gold(delta: int) -> void:
	player.change_gold(delta)


func add_relic(data: RelicData) -> RelicSlot:
	return player.add_relic(data)


func has_relic(data: RelicData) -> bool:
	return player.has_relic(data)


func owned_relics() -> Array[RelicData]:
	return player.owned_relics()


func current_node() -> MapNode:
	return map.node(node_id) if map != null else null


## ノードの中だけの状態を消す（ノードを離れるとき）。全員分。
func clear_node_state() -> void:
	event = null
	for p in players:
		p.clear_node_state()

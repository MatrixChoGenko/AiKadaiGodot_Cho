class_name PlayerState extends RefCounted
## ③ Domain：ラン中のプレイヤー 1 人分のデータ（協力プレイ。GameDesign §21）。1 人プレイでは 1 つだけ。
## RunState の hp / gold / deck などは「いま処理しているプレイヤー」（RunState.active）のこれを指す。

## 協力プレイで 2 人目以降のデッキの uid の始まり（席をまたいでカードの uid が重ならないように）。
const UID_STRIDE: int = 100000

var index: int = 0
var name: String = "プレイヤー"
var hp: int = 0
var max_hp: int = 0
var gold: int = 0
var energy_per_turn: int = 3
var draw_per_turn: int = 5
var deck: Deck = Deck.new()
## 順序 = 発動順。カウンタは RelicSlot.counter（セーブ対象）。
var relics: Array[RelicSlot] = []
var potions: PotionBelt = PotionBelt.new()
var removals_bought: int = 0
var upgrades_bought: int = 0
## 生成済みで受け取り待ちの報酬（REWARD / TREASURE）。
var pending_reward: Reward

# —— ノードの中だけの状態（セーブしない）——
var shop: ShopStock
## 選んだイベントの選択肢（-1 = まだ選んでいない）。
var event_choice: int = -1
## イベントの効果が出したカード選択のリクエスト（先頭から 1 つずつ処理する）。
var pending_requests: Array[RunChoiceRequest] = []
var rest_used: bool = false
## 協力プレイ：このノードで「進む」を押した（全員が押したらマップへ）。
var done: bool = false
## 協力プレイ：マップで投票したノード（-1 = まだ）。
var vote: int = -1


func _init(p_index: int = 0) -> void:
	index = p_index
	deck.next_uid = 1 + p_index * UID_STRIDE


## HP を変える（0〜最大 HP）。実際に変わった量を返す。
func change_hp(delta: int) -> int:
	var before := hp
	hp = clampi(hp + delta, 0, max_hp)
	return hp - before


## HP を減らすが 1 未満にはしない（イベントの HP 減少。GameDesign §7.5）。
func lose_hp_nonlethal(amount: int) -> int:
	var before := hp
	hp = clampi(hp - maxi(amount, 0), mini(1, hp), max_hp)
	return before - hp


func change_max_hp(delta: int) -> void:
	max_hp = maxi(max_hp + delta, 1)
	hp = mini(hp, max_hp)


func change_gold(delta: int) -> void:
	gold = maxi(gold + delta, 0)


func add_relic(data: RelicData) -> RelicSlot:
	var slot := RelicSlot.new(data)
	relics.append(slot)
	return slot


func has_relic(data: RelicData) -> bool:
	for r in relics:
		if r.data == data:
			return true
	return false


func owned_relics() -> Array[RelicData]:
	var result: Array[RelicData] = []
	for r in relics:
		result.append(r.data)
	return result


## ノードの中だけの状態を消す（ノードを離れるとき）。
func clear_node_state() -> void:
	pending_reward = null
	shop = null
	event_choice = -1
	pending_requests.clear()
	rest_used = false
	done = false

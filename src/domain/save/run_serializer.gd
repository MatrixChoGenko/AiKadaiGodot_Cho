class_name RunSerializer extends RefCounted
## ③ Domain：RunState ⇔ Dictionary（JSON にできる形）の変換（Architecture §12.2、Memento）。
## - id と数値だけを保存し、オブジェクト参照は保存しない。アップグレード済みのカードはアップグレード後の id を保存する。
## - マップはシードから作り直さず丸ごと保存する。各乱数ストリームの state とシードは文字列（JSON で 64bit 整数が壊れるため）。
## - 列挙はセーブの互換性のため名前（"MAP" など）で保存する。
## - ノードの中だけの状態（ショップの在庫、イベントの選択など）は保存しない。チェックポイントの位置で必要ないため。
## 読み込みに失敗したら from_dict() は null を返し、理由を error に入れる。

var error: String = ""


## 協力プレイ（GameDesign §21）：プレイヤー 0 は従来どおり最上位に、2 人目以降は coop_players に同じ形で入れる
## （1 人プレイのセーブの形は変わらない）。
static func to_dict(state: RunState) -> Dictionary:
	var d := _player_to_dict(state.players[0])
	d.merge({
		version = SaveMigrations.CURRENT_VERSION,
		seed = str(state.seed_value),
		rng = state.rng.save(),
		act_index = state.act_index,
		map = _map_to_dict(state.map),
		node_id = state.node_id,
		visited = Array(state.visited),
		phase = RunPhase.Id.keys()[state.phase],
		battles_won = state.battles_won,
		queued_encounter = String(state.queued_encounter),
		queued_encounter_rewards = state.queued_encounter_rewards,
		active_encounter = String(state.active_encounter),
		active_encounter_rewards = state.active_encounter_rewards,
	})
	if state.is_coop():
		var others: Array = []
		for i in range(1, state.players.size()):
			others.append(_player_to_dict(state.players[i]))
		d.coop_players = others
	return d


static func _player_to_dict(p: PlayerState) -> Dictionary:
	var cards: Array = []
	for c in p.deck.cards:
		cards.append({uid = c.uid, id = String(c.data.id)})
	var relics: Array = []
	for r in p.relics:
		relics.append({id = String(r.data.id), counter = r.counter})
	var potions: Array = []
	for item in p.potions.slots:
		potions.append(String(item.id) if item != null else "")
	return {
		name = p.name,
		hp = p.hp,
		max_hp = p.max_hp,
		gold = p.gold,
		energy_per_turn = p.energy_per_turn,
		draw_per_turn = p.draw_per_turn,
		deck = {next_uid = p.deck.next_uid, cards = cards},
		relics = relics,
		potions = potions,
		pending_reward = _reward_to_dict(p.pending_reward),
		removals_bought = p.removals_bought,
		upgrades_bought = p.upgrades_bought,
	}


func from_dict(raw: Dictionary, content: ContentLibrary) -> RunState:
	error = ""
	var d := SaveMigrations.migrate(raw)
	if d.is_empty():
		return _fail("unsupported save version: %s" % str(raw.get("version", "none")))
	var s := RunState.new()
	s.seed_value = String(d.get("seed", "0")).to_int()
	s.rng = RngStreams.new(s.seed_value)
	s.rng.restore(d.get("rng", {}))
	var others: Array = d.get("coop_players", [])
	s.set_player_count(1 + others.size())
	if not _player_from_dict(d, s.players[0], content):
		return null
	for i in others.size():
		if not _player_from_dict(others[i], s.players[i + 1], content):
			return null
	s.act_index = int(d.get("act_index", 0))
	s.map = _map_from_dict(d.get("map", {}))
	if s.map == null:
		return null
	s.node_id = int(d.get("node_id", -1))
	for id: Variant in d.get("visited", []):
		s.visited.append(int(id))
	var phase := RunPhase.Id.keys().find(String(d.get("phase", "")))
	if phase < 0:
		return _fail("unknown phase: %s" % d.get("phase"))
	s.phase = phase as RunPhase.Id
	s.battles_won = int(d.get("battles_won", 0))
	s.queued_encounter = StringName(d.get("queued_encounter", ""))
	s.queued_encounter_rewards = bool(d.get("queued_encounter_rewards", true))
	s.active_encounter = StringName(d.get("active_encounter", ""))
	s.active_encounter_rewards = bool(d.get("active_encounter_rewards", true))
	if s.phase == RunPhase.Id.COMBAT and content.encounter(s.active_encounter) == null:
		return _fail("unknown active encounter: %s" % s.active_encounter)
	if s.phase in [RunPhase.Id.REWARD]:
		for p in s.players:
			if p.pending_reward == null:
				return _fail("reward phase without a reward")
	return s


## 1 人分を読む。失敗したら false（理由は error）。
func _player_from_dict(d: Dictionary, p: PlayerState, content: ContentLibrary) -> bool:
	p.name = String(d.get("name", p.name))
	p.hp = int(d.get("hp", 0))
	p.max_hp = int(d.get("max_hp", 1))
	p.gold = int(d.get("gold", 0))
	p.energy_per_turn = int(d.get("energy_per_turn", 3))
	p.draw_per_turn = int(d.get("draw_per_turn", 5))
	var deck: Dictionary = d.get("deck", {})
	for c: Dictionary in deck.get("cards", []):
		var data := content.card(StringName(c.get("id", "")))
		if data == null:
			_fail("unknown card: %s" % c.get("id"))
			return false
		p.deck.cards.append(Card.new(int(c.get("uid", 0)), data))
	p.deck.next_uid = int(deck.get("next_uid", 1))
	for r: Dictionary in d.get("relics", []):
		var data := content.relic(StringName(r.get("id", "")))
		if data == null:
			_fail("unknown relic: %s" % r.get("id"))
			return false
		p.add_relic(data).counter = int(r.get("counter", 0))
	var potions: Array = d.get("potions", [])
	p.potions = PotionBelt.new(potions.size())
	for i in potions.size():
		if String(potions[i]) != "":
			var data := content.potion(StringName(potions[i]))
			if data == null:
				_fail("unknown potion: %s" % potions[i])
				return false
			p.potions.slots[i] = data
	if d.get("pending_reward") != null:
		p.pending_reward = _reward_from_dict(d["pending_reward"], content)
		if p.pending_reward == null:
			return false
	p.removals_bought = int(d.get("removals_bought", 0))
	p.upgrades_bought = int(d.get("upgrades_bought", 0))
	return true


# —— マップ ——

static func _map_to_dict(map: MapGraph) -> Dictionary:
	if map == null:
		return {}
	var nodes: Array = []
	for n in map.nodes:
		nodes.append({
			id = n.id, row = n.row, col = n.col,
			type = MapNode.Type.keys()[n.type],
			next = Array(n.next),
			encounter = String(n.encounter),
			event = String(n.event),
		})
	return {rows = map.rows, columns = map.columns, boss_id = map.boss_id, nodes = nodes}


func _map_from_dict(d: Dictionary) -> MapGraph:
	var map := MapGraph.new()
	map.rows = int(d.get("rows", 0))
	map.columns = int(d.get("columns", 0))
	map.boss_id = int(d.get("boss_id", -1))
	var nodes: Array = d.get("nodes", [])
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var n := MapNode.new(int(nd.get("id", -1)), int(nd.get("row", 0)), int(nd.get("col", 0)))
		if n.id != i:
			return _fail("map node id mismatch at %d" % i)
		var t := MapNode.Type.keys().find(String(nd.get("type", "")))
		if t < 0:
			return _fail("unknown map node type: %s" % nd.get("type"))
		n.type = t as MapNode.Type
		for id: Variant in nd.get("next", []):
			n.next.append(int(id))
		n.encounter = StringName(nd.get("encounter", ""))
		n.event = StringName(nd.get("event", ""))
		map.nodes.append(n)
	if map.node(map.boss_id) == null:
		return _fail("map has no boss")
	return map


# —— 報酬 ——

static func _reward_to_dict(reward: Reward) -> Variant:
	if reward == null:
		return null
	var items: Array = []
	for item in reward.items:
		var cards: Array = []
		for c in item.cards:
			cards.append(String(c.id))
		items.append({
			kind = RewardItem.Kind.keys()[item.kind],
			gold = item.gold,
			cards = cards,
			relic = String(item.relic.id) if item.relic != null else "",
			potion = String(item.potion.id) if item.potion != null else "",
			taken = item.taken,
		})
	return {items = items}


func _reward_from_dict(d: Dictionary, content: ContentLibrary) -> Reward:
	var reward := Reward.new()
	for raw: Dictionary in d.get("items", []):
		var item := RewardItem.new()
		var kind := RewardItem.Kind.keys().find(String(raw.get("kind", "")))
		if kind < 0:
			return _fail("unknown reward kind: %s" % raw.get("kind"))
		item.kind = kind as RewardItem.Kind
		item.gold = int(raw.get("gold", 0))
		for id: Variant in raw.get("cards", []):
			var card := content.card(StringName(id))
			if card == null:
				return _fail("unknown card in reward: %s" % id)
			item.cards.append(card)
		if String(raw.get("relic", "")) != "":
			item.relic = content.relic(StringName(raw["relic"]))
			if item.relic == null:
				return _fail("unknown relic in reward: %s" % raw["relic"])
		if String(raw.get("potion", "")) != "":
			item.potion = content.potion(StringName(raw["potion"]))
			if item.potion == null:
				return _fail("unknown potion in reward: %s" % raw["potion"])
		item.taken = bool(raw.get("taken", false))
		reward.add(item)
	return reward


func _fail(message: String) -> Variant:
	error = message
	return null

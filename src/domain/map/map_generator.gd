class_name MapGenerator extends RefCounted
## ③ Domain：マップの生成（GameDesign §4.1、付録 C の C30・C33）。
## 乱数：形と種類は map、エンカウントの割り当てとボスは encounter、イベントの割り当ては event ストリーム。
## 集合から選ぶときは必ず順番を決めて（id / 行・列の順）から乱数で選ぶ（Dictionary の順番に依存しない）。

## RunConfig.node_weights の並び。
const WEIGHTED_TYPES: Array[MapNode.Type] = [MapNode.Type.BATTLE, MapNode.Type.EVENT, MapNode.Type.ELITE,
		MapNode.Type.REST, MapNode.Type.SHOP]
const SPECIAL_TYPES: Array[MapNode.Type] = [MapNode.Type.ELITE, MapNode.Type.REST, MapNode.Type.SHOP]


static func generate(rng: RngStreams, act: ActData, content: ContentLibrary, config: RunConfig) -> MapGraph:
	var map := _build_shape(rng, act)
	_assign_types(rng, map, config)
	_guarantee_shops(rng, map, config)
	_assign_contents(rng, map, act, content, config)
	return map


## アクトに出るエンカウント（rank で絞る）。id 順。
static func encounters_for(act_number: int, content: ContentLibrary, rank: EnemyData.Rank) -> Array[EncounterData]:
	var result: Array[EncounterData] = []
	for e in content.encounters:
		if e.rank == rank and e.acts & (1 << (act_number - 1)) != 0:
			result.append(e)
	result.sort_custom(func(a: EncounterData, b: EncounterData) -> bool: return String(a.id) < String(b.id))
	return result


## その行の通常戦闘の候補。序盤の行は early のものだけ（無ければ全部）。id 順。
static func normal_encounters_for_row(act_number: int, content: ContentLibrary, config: RunConfig, row: int) -> Array[EncounterData]:
	var normal := encounters_for(act_number, content, EnemyData.Rank.NORMAL)
	if row >= config.early_battle_rows:
		return normal
	var early: Array[EncounterData] = []
	for e in normal:
		if e.early:
			early.append(e)
	return normal if early.is_empty() else early


## 特殊なノードがその行に出られるか。
static func _special_allowed(t: MapNode.Type, row: int, config: RunConfig) -> bool:
	var min_row := config.elite_min_row if t == MapNode.Type.ELITE else config.rest_shop_min_row
	return row >= min_row


# —— 形：パスを引き、通ったマスだけをノードにする ——

static func _build_shape(rng: RngStreams, act: ActData) -> MapGraph:
	var rows := act.rows
	var cols := act.columns
	var cells: Dictionary[int, bool] = {}      # row * cols + col
	var edges: Dictionary[int, bool] = {}      # _edge_key(row, from_col, to_col)
	var first_start := -1
	for p in act.paths:
		var col := rng.range_int(&"map", 0, cols - 1)
		if p == 1 and cols > 1:
			# 少なくとも 2 つの異なる開始地点。
			var others: Array[int] = []
			for c in cols:
				if c != first_start:
					others.append(c)
			col = rng.pick(&"map", others) as int
		if p == 0:
			first_start = col
		cells[col] = true
		for r in rows - 1:
			var steps: Array[int] = []
			for d in [-1, 0, 1]:
				if col + d >= 0 and col + d < cols:
					steps.append(d)
			rng.shuffle(&"map", steps)
			var step := 0
			for d in steps:
				# 斜めに進むとき、逆向きの斜めの線が既にあれば交差するので選ばない（C30）。真上は交差しない。
				if d != 0 and edges.has(_edge_key(r, col + d, col, cols)):
					continue
				step = d
				break
			edges[_edge_key(r, col, col + step, cols)] = true
			col += step
			cells[(r + 1) * cols + col] = true

	var map := MapGraph.new()
	map.rows = rows
	map.columns = cols
	var id_of: Dictionary[int, int] = {}
	for r in rows:
		for c in cols:
			if cells.has(r * cols + c):
				id_of[r * cols + c] = map.nodes.size()
				map.nodes.append(MapNode.new(map.nodes.size(), r, c))
	var boss := MapNode.new(map.nodes.size(), rows, cols >> 1)
	boss.type = MapNode.Type.BOSS
	map.boss_id = boss.id
	for n in map.nodes:
		if n.row == rows - 1:
			n.next.append(boss.id)
			continue
		for c in [n.col - 1, n.col, n.col + 1]:
			if c >= 0 and c < cols and edges.has(_edge_key(n.row, n.col, c, cols)):
				n.next.append(id_of[(n.row + 1) * cols + c])
	map.nodes.append(boss)
	return map


static func _edge_key(row: int, from_col: int, to_col: int, cols: int) -> int:
	return (row * cols + from_col) * cols + to_col


# —— 種類 ——

static func _assign_types(rng: RngStreams, map: MapGraph, config: RunConfig) -> void:
	for n in map.nodes:
		if n.type == MapNode.Type.BOSS:
			continue
		var fixed := _fixed_type(n.row, map.rows)
		if fixed >= 0:
			n.type = fixed as MapNode.Type
			continue
		n.type = MapNode.Type.BATTLE
		var parents := map.parents_of(n.id)
		for attempt in config.node_reroll_limit:
			var t := WEIGHTED_TYPES[maxi(rng.weighted(&"map", config.node_weights), 0)]
			if t in SPECIAL_TYPES:
				if not _special_allowed(t, n.row, config) or _any_of_type(parents, t):
					continue
			n.type = t
			break


## 固定の種類の行なら種類、そうでなければ -1。0 行目 = 戦闘、中間の行 = 宝箱、ボスの 1 つ手前 = 休憩。
static func _fixed_type(row: int, rows: int) -> int:
	if row == 0:
		return MapNode.Type.BATTLE
	if row == rows - 1:
		return MapNode.Type.REST
	if row == rows >> 1:   # rows / 2
		return MapNode.Type.TREASURE
	return -1


static func _any_of_type(list: Array[MapNode], t: MapNode.Type) -> bool:
	for n in list:
		if n.type == t:
			return true
	return false


# —— ショップの保証：最低 min_shops 軒、どの開始地点からもショップを通るルートがある ——

static func _guarantee_shops(rng: RngStreams, map: MapGraph, config: RunConfig) -> void:
	for guard in map.nodes.size():
		var candidates: Array[MapNode] = []
		var bad_start := _start_without_shop(map)
		if bad_start != null:
			for id in map.reachable_from(bad_start.id):
				if _can_become_shop(map, map.node(id), config):
					candidates.append(map.node(id))
		elif map.count_of(MapNode.Type.SHOP) < config.min_shops:
			for n in map.nodes:
				if _can_become_shop(map, n, config):
					candidates.append(n)
		else:
			return
		# 戦闘 / イベントを優先して置き換える（エリート・休憩を減らさない）。
		var plain: Array[MapNode] = []
		for n in candidates:
			if n.type in [MapNode.Type.BATTLE, MapNode.Type.EVENT]:
				plain.append(n)
		if not plain.is_empty():
			candidates = plain
		if candidates.is_empty():
			return   # 小さすぎるマップなど。保証できない
		(rng.pick(&"map", candidates) as MapNode).type = MapNode.Type.SHOP


static func _start_without_shop(map: MapGraph) -> MapNode:
	for s in map.start_nodes():
		var found := false
		for id in map.reachable_from(s.id):
			if map.node(id).type == MapNode.Type.SHOP:
				found = true
				break
		if not found:
			return s
	return null


static func _can_become_shop(map: MapGraph, n: MapNode, config: RunConfig) -> bool:
	if n.type in [MapNode.Type.SHOP, MapNode.Type.BOSS] or not _special_allowed(MapNode.Type.SHOP, n.row, config):
		return false
	if _fixed_type(n.row, map.rows) >= 0:
		return false
	if _any_of_type(map.parents_of(n.id), MapNode.Type.SHOP):
		return false
	for id in n.next:
		if map.node(id).type == MapNode.Type.SHOP:
			return false
	return true


# —— 内容：シャッフルバッグ（使い切るまで重複しない。空になったら詰め直す。C31） ——

static func _assign_contents(rng: RngStreams, map: MapGraph, act: ActData, content: ContentLibrary, config: RunConfig) -> void:
	var normal := normal_encounters_for_row(act.number, content, config, config.early_battle_rows)
	var early := normal_encounters_for_row(act.number, content, config, 0)
	var elite := encounters_for(act.number, content, EnemyData.Rank.ELITE)
	var events: Array[EventData] = []
	for e in content.events:
		if e.acts & (1 << (act.number - 1)) != 0:
			events.append(e)
	events.sort_custom(func(a: EventData, b: EventData) -> bool: return String(a.id) < String(b.id))
	var normal_bag: Array = []
	var early_bag: Array = []
	var elite_bag: Array = []
	var event_bag: Array = []
	for n in map.nodes:
		match n.type:
			MapNode.Type.EVENT:
				var row := n.row
				var ev: EventData = _draw(rng, &"event", event_bag, events,
						func(x: EventData) -> bool: return x.min_row <= row)
				if ev != null:
					n.event = ev.id
				else:
					n.type = MapNode.Type.BATTLE   # イベントのプールが空なら通常戦闘に格下げ
			MapNode.Type.ELITE:
				var enc: EncounterData = _draw(rng, &"encounter", elite_bag, elite, Callable())
				if enc != null:
					n.encounter = enc.id
				else:
					n.type = MapNode.Type.BATTLE   # エリートのプールが空なら通常戦闘に格下げ
		if n.type == MapNode.Type.BATTLE:
			var enc: EncounterData
			if n.row < config.early_battle_rows:
				enc = _draw(rng, &"encounter", early_bag, early, Callable())
			else:
				enc = _draw(rng, &"encounter", normal_bag, normal, Callable())
			if enc != null:
				n.encounter = enc.id
	var bosses := act.bosses.duplicate()
	bosses.sort_custom(func(a: EncounterData, b: EncounterData) -> bool: return String(a.id) < String(b.id))
	var boss: EncounterData = rng.pick(&"encounter", bosses)
	if boss != null:
		map.boss().encounter = boss.id


## バッグから accept を満たす最初のものを取り出す。見つからなければ詰め直してもう一度探す。それでも無ければ null。
static func _draw(rng: RngStreams, stream: StringName, bag: Array, pool: Array, accept: Callable) -> Variant:
	var refilled := false
	if bag.is_empty():
		_refill(rng, stream, bag, pool)
		refilled = true
	var i := _find(bag, accept)
	if i < 0 and not refilled:
		_refill(rng, stream, bag, pool)
		i = _find(bag, accept)
	return bag.pop_at(i) if i >= 0 else null


static func _refill(rng: RngStreams, stream: StringName, bag: Array, pool: Array) -> void:
	var items := pool.duplicate()
	rng.shuffle(stream, items)
	bag.append_array(items)


static func _find(bag: Array, accept: Callable) -> int:
	for i in bag.size():
		if not accept.is_valid() or accept.call(bag[i]):
			return i
	return -1

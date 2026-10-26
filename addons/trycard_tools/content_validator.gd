@tool
class_name ContentValidator extends RefCounted
## コンテンツバリデータ（Architecture §17.3）。エディタプラグインとテストで共用する。
## エディタ上では @tool でないコンテンツのスクリプトのメソッドは動かないため、メソッド（children() など）は呼ばず、
## エクスポートされたプロパティを汎用に辿って検査する。

## これらの型は「単独のコンテンツ」。他から参照されているときは中へ辿らず、インデックスにあることだけを確かめる。
const TOP_LEVEL_TYPES: Array[String] = [
	"CardData", "StatusData", "KeywordData", "RelicData", "PotionData",
	"EnemyData", "EncounterData", "EventData", "ActData", "RunConfig",
]
## ステートレスでなければならないブロック（Architecture §21 ルール 2）。基底クラス名で判定する。
const STATELESS_BASES: Array[String] = [
	"CardEffect", "ValueSource", "Condition", "TargetRule", "CombatBehavior",
	"EnemyAI", "RunEffect", "RunCondition", "WeightedEffects",
]
## null であってはならないフィールド（クラス名 → プロパティ名）。
const REQUIRED: Dictionary = {
	"DamageEffect": ["amount", "target"],
	"BlockEffect": ["amount"],
	"ApplyStatusEffect": ["status", "stacks", "target"],
	"RemoveStatusesEffect": ["target"],
	"HealEffect": ["amount"],
	"LoseHpEffect": ["amount"],
	"GainEnergyEffect": ["amount"],
	"DrawEffect": ["count"],
	"CreateCardEffect": ["count"],
	"ConsumeStatusEffect": ["status", "target"],
	"SpreadStatusEffect": ["status", "target", "spread_to"],
	"RepeatEffect": ["times"],
	"BranchEffect": ["when"],
	"ScaledValue": ["unit"],
	"IfValue": ["when", "then", "otherwise"],
	"StatusStacksValue": ["status"],
	"HasStatusCondition": ["status"],
	"CompareCondition": ["left", "right"],
	"GrantStatusOnTurnStart": ["status"],
	"GrantStatusOnCombatStart": ["status"],
	"BranchRunEffect": ["when"],
	"HasRelicRunCondition": ["relic"],
	"HasCardRunCondition": ["card"],
	"EnemyData": ["ai"],
}
const ID_PATTERN: String = "^[a-z][a-z0-9_]*$"
const PLACEHOLDER_PATTERN: String = "\\{([A-Za-z0-9_]+)\\}"

var _report: ValidationReport
var _indexed: Dictionary = {}          # instance_id -> true（インデックスに載っているコンテンツ）
var _visited: Dictionary = {}          # instance_id -> true
var _checked_scripts: Dictionary = {}  # Script -> true
var _id_regex: RegEx
var _placeholder_regex: RegEx


func _init() -> void:
	_id_regex = RegEx.create_from_string(ID_PATTERN)
	_placeholder_regex = RegEx.create_from_string(PLACEHOLDER_PATTERN)


func validate(lib: ContentLibrary) -> ValidationReport:
	_report = ValidationReport.new()
	_indexed.clear()
	_visited.clear()
	_checked_scripts.clear()
	if lib == null:
		_report.error("library", "ContentLibrary is null")
		return _report
	var all_top: Array[Resource] = []
	all_top.append_array(lib.cards)
	all_top.append_array(lib.statuses)
	all_top.append_array(lib.keywords)
	all_top.append_array(lib.relics)
	all_top.append_array(lib.potions)
	all_top.append_array(lib.enemies)
	all_top.append_array(lib.encounters)
	all_top.append_array(lib.events)
	all_top.append_array(lib.acts)
	if lib.config != null:
		all_top.append(lib.config)
	else:
		_report.error("library", "RunConfig is missing")
	for res in all_top:
		if res == null:
			_report.error("library", "null entry in the index (rebuild the content index)")
			continue
		_indexed[res.get_instance_id()] = true
	for res in all_top:
		if res != null:
			_walk(res, _where(res))

	_check_ids(lib)
	_check_keywords(lib)
	for c in lib.cards:
		if c != null:
			_check_card(c)
	for s in lib.statuses:
		if s != null:
			_check_text_placeholders(_where(s), s.text, PackedStringArray(["stacks"]), false)
	for p in lib.potions:
		if p != null:
			_check_effect_owner(_where(p), p.text, p.aim, [p.effects], [])
	for e in lib.enemies:
		if e != null:
			_check_enemy(e)
	for enc in lib.encounters:
		if enc != null:
			_check_encounter(enc)
	for ev in lib.events:
		if ev != null:
			_check_event(ev)
	for a in lib.acts:
		if a != null:
			_check_act(a)
	if lib.config != null:
		_check_config(lib)
	return _report


# —— 汎用の走査（null 参照、未登録の参照、ステートレス性）——

func _walk(res: Resource, where: String) -> void:
	var key := res.get_instance_id()
	if _visited.has(key):
		return
	_visited[key] = true
	var cname := _class_name(res)
	if REQUIRED.has(cname):
		for field: String in REQUIRED[cname]:
			if res.get(field) == null:
				_report.error(where, "%s.%s must not be null" % [cname, field])
	if _is_block(res):
		_check_stateless(res.get_script() as Script, cname)
	for prop in _stored_properties(res):
		var name: String = prop["name"]
		_walk_value(res.get(name), "%s.%s" % [where, name])


func _walk_value(value: Variant, where: String) -> void:
	if value is Resource:
		var res := value as Resource
		if _is_top_level(res):
			if not _indexed.has(res.get_instance_id()):
				_report.error(where, "references %s that is not in the content index" % _where(res))
		else:
			_walk(res, where)
	elif value is Array:
		var arr := value as Array
		for i in arr.size():
			if arr[i] == null and arr.is_typed() and arr.get_typed_builtin() == TYPE_OBJECT:
				_report.error(where, "null entry at [%d]" % i)
			else:
				_walk_value(arr[i], "%s[%d]" % [where, i])
	elif value is Dictionary:
		var dict := value as Dictionary
		for k: Variant in dict:
			if k == null:
				_report.error(where, "null key")
			_walk_value(k, "%s{key}" % where)
			_walk_value(dict[k], "%s{value}" % where)


func _check_stateless(script: Script, cname: String) -> void:
	if script == null or _checked_scripts.has(script):
		return
	_checked_scripts[script] = true
	for prop in script.get_script_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not usage & PROPERTY_USAGE_STORAGE:
			_report.error(script.resource_path, "%s has non-exported member '%s' (blocks must be stateless)" % [cname, prop["name"]])


# —— 種類ごとの検査 ——

func _check_ids(lib: ContentLibrary) -> void:
	var groups: Dictionary = {
		"card": lib.cards, "status": lib.statuses, "keyword": lib.keywords, "relic": lib.relics,
		"potion": lib.potions, "enemy": lib.enemies, "encounter": lib.encounters, "event": lib.events, "act": lib.acts,
	}
	for kind: String in groups:
		var seen: Dictionary = {}
		for res: Resource in groups[kind]:
			if res == null:
				continue
			var id: String = String(res.get("id"))
			if id.is_empty():
				_report.error(_where(res), "%s id is empty" % kind)
				continue
			if _id_regex.search(id) == null:
				_report.error(_where(res), "%s id '%s' must be lower_snake_case" % [kind, id])
			if seen.has(id):
				_report.error(_where(res), "duplicate %s id '%s' (also %s)" % [kind, id, seen[id]])
			seen[id] = _where(res)
			var name_field := "title" if res is EventData else "name"
			if String(res.get(name_field)).strip_edges().is_empty():
				_report.error(_where(res), "%s is empty" % name_field)


func _check_keywords(lib: ContentLibrary) -> void:
	var have: Dictionary = {}
	for k in lib.keywords:
		if k == null:
			continue
		if have.has(k.kind):
			_report.error(_where(k), "duplicate KeywordData for kind %d" % k.kind)
		have[k.kind] = true
	for c in lib.cards:
		if c == null:
			continue
		for bit: int in [CardData.Keyword.EXHAUST, CardData.Keyword.RETAIN, CardData.Keyword.INNATE, CardData.Keyword.ETHEREAL]:
			if c.keywords & bit and not have.has(bit):
				_report.error(_where(c), "uses keyword bit %d but there is no KeywordData for it" % bit)
		if c.cost_mode == CardData.CostMode.UNPLAYABLE and not have.has(KeywordData.Kind.UNPLAYABLE):
			_report.error(_where(c), "is unplayable but there is no KeywordData for UNPLAYABLE")


func _check_card(c: CardData) -> void:
	var where := _where(c)
	_check_effect_owner(where, c.text, c.aim, [c.on_play], [c.on_draw, c.on_discard, c.on_exhaust, c.end_of_turn_in_hand])
	if c.cost_mode == CardData.CostMode.UNPLAYABLE and not c.on_play.is_empty():
		_report.error(where, "unplayable card has on_play effects")
	# アップグレードの連鎖に循環がない。
	var seen: Dictionary = {}
	var cur := c
	while cur != null:
		if seen.has(cur.get_instance_id()):
			_report.error(where, "upgrade chain has a cycle")
			break
		seen[cur.get_instance_id()] = true
		cur = cur.upgraded
	if c.upgraded != null and c.upgraded.type != c.type:
		_report.warn(where, "upgraded card has a different type")


## カード / ポーション共通：テキストのプレースホルダと効果の label の対応、aim と対象の一致。
## play_lists = プレイ時に解決されるリスト（選んだ対象を使える）、other_lists = トリガーのリスト（選んだ対象は無い）。
func _check_effect_owner(where: String, text: String, aim: CardData.Aim, play_lists: Array, other_lists: Array) -> void:
	var labels := PackedStringArray()
	var play_nodes: Array[Resource] = []
	for list: Array in play_lists:
		_descendants(list, play_nodes)
	var other_nodes: Array[Resource] = []
	for list: Array in other_lists:
		_descendants(list, other_nodes)
	for node in play_nodes + other_nodes:
		if node is CardEffect:
			var label := String((node as CardEffect).label)
			if not label.is_empty():
				if label in labels:
					_report.error(where, "duplicate effect label '%s'" % label)
				labels.append(label)
	_check_text_placeholders(where, text, labels, true)
	var uses_chosen := play_nodes.any(func(n: Resource) -> bool: return n is ChosenTarget)
	if uses_chosen and aim != CardData.Aim.ENEMY:
		_report.error(where, "effects use ChosenTarget but aim is not ENEMY")
	if not uses_chosen and aim == CardData.Aim.ENEMY:
		_report.error(where, "aim is ENEMY but no effect uses ChosenTarget")
	if other_nodes.any(func(n: Resource) -> bool: return n is ChosenTarget):
		_report.error(where, "trigger effects (draw / discard / exhaust / end of turn) cannot use ChosenTarget")


func _check_text_placeholders(where: String, text: String, labels: PackedStringArray, labels_must_be_used: bool) -> void:
	var used := PackedStringArray()
	for m in _placeholder_regex.search_all(text):
		var key := m.get_string(1)
		used.append(key)
		if not key in labels:
			_report.error(where, "text placeholder {%s} has no matching effect label" % key)
	if labels_must_be_used:
		for label in labels:
			if not label in used:
				_report.error(where, "effect label '%s' is not used in the text" % label)


func _check_enemy(e: EnemyData) -> void:
	var where := _where(e)
	if e.hp_min > e.hp_max:
		_report.error(where, "hp_min > hp_max")
	if e.moves.is_empty():
		_report.error(where, "has no moves")
	var ids: Dictionary = {}
	for m in e.moves:
		if m == null:
			continue
		if String(m.id).is_empty():
			_report.error(where, "a move has an empty id")
		elif ids.has(m.id):
			_report.error(where, "duplicate move id '%s'" % m.id)
		ids[m.id] = true
		if m.name.strip_edges().is_empty():
			_report.error(where, "move '%s' has no name" % m.id)
		if m.effects.is_empty():
			_report.error(where, "move '%s' has no effects" % m.id)
		if m.priority > 0 and m.forced_when == null:
			_report.error(where, "move '%s' has priority but no forced_when" % m.id)
	if e.ai is ScriptedAI:
		var ai := e.ai as ScriptedAI
		for step in ai.opening:
			if not ids.has(step):
				_report.error(where, "ai.opening refers to unknown move '%s'" % step)
		var weighted := e.moves.any(func(m: EnemyMove) -> bool: return m != null and m.weight > 0)
		if not weighted and not ai.loop_opening:
			_report.error(where, "no move has weight > 0 and the opening does not loop")


func _check_encounter(enc: EncounterData) -> void:
	if enc.enemies.is_empty():
		_report.error(_where(enc), "has no enemies")
	var top := EnemyData.Rank.NORMAL
	for e in enc.enemies:
		if e != null and e.rank > top:
			top = e.rank
	if top != enc.rank:
		_report.warn(_where(enc), "rank differs from the strongest enemy's rank")


func _check_event(ev: EventData) -> void:
	if ev.options.is_empty():
		_report.error(_where(ev), "has no options")
	for i in ev.options.size():
		var o := ev.options[i]
		if o != null and o.text.strip_edges().is_empty():
			_report.error(_where(ev), "option %d has no text" % i)
		if o != null and o.requires != null and o.disabled_hint.strip_edges().is_empty():
			_report.warn(_where(ev), "option %d has requires but no disabled_hint" % i)


func _check_act(a: ActData) -> void:
	if a.bosses.is_empty():
		_report.error(_where(a), "has no bosses")
	for b in a.bosses:
		if b != null and b.rank != EnemyData.Rank.BOSS:
			_report.error(_where(a), "boss encounter '%s' is not BOSS rank" % b.id)


func _check_config(lib: ContentLibrary) -> void:
	var cfg := lib.config
	var where := _where(cfg)
	if cfg.starting_deck.is_empty():
		_report.error(where, "starting_deck is empty")
	var sizes: Dictionary = {
		"card_rarity_weights": 3, "potion_rarity_weights": 3, "relic_rarity_weights": 3,
		"card_prices": CardData.Rarity.size(), "relic_prices": RelicData.Rarity.size(),
		"potion_prices": PotionData.Rarity.size(), "node_weights": 5,
	}
	for field: String in sizes:
		var arr: PackedInt32Array = cfg.get(field)
		if arr.size() != sizes[field]:
			_report.error(where, "%s must have %d entries (has %d)" % [field, sizes[field], arr.size()])
	# エディタ上では ContentLibrary のメソッドが動かないので、ここで数える。
	for rarity: CardData.Rarity in [CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON, CardData.Rarity.RARE]:
		var count := lib.cards.filter(func(c: CardData) -> bool: return c != null and c.rarity == rarity).size()
		if count < cfg.reward_card_count:
			_report.warn(where, "fewer than %d cards of rarity %s" % [cfg.reward_card_count, CardData.Rarity.keys()[rarity]])


# —— ヘルパ ——

## value（Resource / Array）から辿れる、単独のコンテンツ以外のすべての Resource を out に集める。
func _descendants(value: Variant, out: Array[Resource]) -> void:
	if value is Resource:
		var res := value as Resource
		if _is_top_level(res) or out.has(res):
			return
		out.append(res)
		for prop in _stored_properties(res):
			_descendants(res.get(prop["name"]), out)
	elif value is Array:
		for item: Variant in value:
			_descendants(item, out)


func _stored_properties(res: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for prop in res.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			result.append(prop)
	return result


func _is_top_level(res: Resource) -> bool:
	return _class_name(res) in TOP_LEVEL_TYPES


func _is_block(res: Resource) -> bool:
	var script := res.get_script() as Script
	while script != null:
		if script.get_global_name() in STATELESS_BASES:
			return true
		script = script.get_base_script()
	return false


func _class_name(res: Resource) -> String:
	var script := res.get_script() as Script
	return script.get_global_name() if script != null else res.get_class()


func _where(res: Resource) -> String:
	if not res.resource_path.is_empty():
		return res.resource_path
	var id: Variant = res.get("id")
	return "%s(%s)" % [_class_name(res), id if id != null else "?"]

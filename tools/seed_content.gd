extends SceneTree
## GameDesign.md 付録 A（と §21 の M1 決定事項）に従って、全コンテンツの .tres を一括生成する（Architecture §17.4）。
## 最初の 1 回だけ使う。以後のコンテンツはエディタの Inspector で保守する。
## 生成後にコンテンツインデックスを再構築し、ContentValidator で検証する。検証エラーがあれば終了コード 1。
##
## 実行：Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/seed_content.gd -- [--force]
##   --force：content/ 以下の既存の .tres をすべて削除してから作り直す（Inspector での編集は失われる）。

const CONTENT_DIR: String = "res://content"
## カードの絵（assets/textures/card_art/）があれば入れる。
const CardArt = preload("res://tools/card_art.gd")

const ATK: int = CardData.TYPE_BIT_ATTACK
const SKL: int = CardData.TYPE_BIT_SKILL
const STATUS_OR_CURSE: int = CardData.TYPE_BIT_STATUS | CardData.TYPE_BIT_CURSE
const EXH: int = CardData.Keyword.EXHAUST
const RET: int = CardData.Keyword.RETAIN
const INN: int = CardData.Keyword.INNATE
const ETH: int = CardData.Keyword.ETHEREAL
## _add_card の cost に渡す特別な値。
const COST_X: int = -1
const UNPLAYABLE: int = -2

var _paths: Dictionary = {}      # Resource -> 保存先のパス
var _saved: Dictionary = {}      # Resource -> true
var _statuses: Dictionary = {}   # id -> StatusData
var _cards: Dictionary = {}      # id -> CardData
var _relics: Dictionary = {}
var _enemies: Dictionary = {}
var _encounters: Dictionary = {}

var _t_chosen: ChosenTarget
var _t_self: SelfTarget
var _t_all: AllEnemiesTarget
var _t_random: RandomEnemiesTarget
var _t_others: AllEnemiesTarget


func _init() -> void:
	var force := "--force" in OS.get_cmdline_user_args()
	if not ContentIndexBuilder.list_resources(CONTENT_DIR).is_empty():
		if not force:
			printerr("seed_content: content/ already has .tres files. Use -- --force to delete and regenerate them.")
			quit(1)
			return
		for path in ContentIndexBuilder.list_resources(CONTENT_DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	_build_presets()
	_build_statuses()
	_build_keywords()
	_build_cards()
	_build_potions()
	_build_relics()
	_build_enemies()
	_build_encounters()
	_build_events()
	_build_acts()
	_build_config()

	for res: Resource in _paths:
		_save(res)
	print("seed_content: wrote %d resources" % _saved.size())

	var lib := ContentIndexBuilder.rebuild()
	var report := ContentValidator.new().validate(lib)
	print(report)
	quit(0 if report.ok() else 1)


# —— 保存（参照先を先に保存し、参照は ext_resource になるようにする）——

func _register(res: Resource, path: String) -> void:
	_paths[res] = CONTENT_DIR.path_join(path)


func _save(res: Resource) -> void:
	if _saved.has(res):
		return
	_saved[res] = true
	var deps: Array[Resource] = []
	_collect_deps(res, deps, true)
	for dep in deps:
		_save(dep)
	var path: String = _paths[res]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("seed_content: failed to save %s (%s)" % [path, error_string(err)])
	# パスを持たせると、後で保存するリソースからの参照が埋め込みではなく ext_resource になる。
	res.take_over_path(path)


## res から辿れる、別ファイルとして保存するリソース（_paths に登録済み）を集める。
func _collect_deps(value: Variant, out: Array[Resource], is_root: bool = false) -> void:
	if value is Resource:
		var res := value as Resource
		if not is_root and _paths.has(res):
			if not out.has(res):
				out.append(res)
			return
		for prop in res.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_collect_deps(res.get(prop["name"]), out)
	elif value is Array:
		for item: Variant in value:
			_collect_deps(item, out)
	elif value is Dictionary:
		for k: Variant in value:
			_collect_deps(k, out)
			_collect_deps((value as Dictionary)[k], out)


# —— プリセット（共有する対象ルール）——

func _build_presets() -> void:
	_t_chosen = ChosenTarget.new()
	_register(_t_chosen, "presets/target_chosen.tres")
	_t_self = SelfTarget.new()
	_register(_t_self, "presets/target_self.tres")
	_t_all = AllEnemiesTarget.new()
	_register(_t_all, "presets/target_all_enemies.tres")
	_t_random = RandomEnemiesTarget.new()
	_register(_t_random, "presets/target_random_enemy.tres")
	_t_others = AllEnemiesTarget.new()
	_t_others.exclude_chosen = true
	_register(_t_others, "presets/target_other_enemies.tres")


# —— ステータス / キーワード ——

func _build_statuses() -> void:
	var B := StatusData.Polarity.BUFF
	var D := StatusData.Polarity.DEBUFF
	var NONE := StatusData.Decay.NONE
	var ROUND := StatusData.Decay.LOSE_ONE_AT_ROUND_END

	var flat := FlatDamageBonus.new()
	_add_status("strength", "筋力", B, NONE, 999, [flat], "攻撃ダメージが {stacks} 増える。")
	var vuln := DamagePercent.new()
	vuln.direction = DamagePercent.Direction.INCOMING
	vuln.percent = 50
	_add_status("vulnerable", "脆弱", D, ROUND, 999, [vuln], "受ける攻撃ダメージが 50% 増える。残り {stacks} ラウンド。")
	var weak := DamagePercent.new()
	weak.direction = DamagePercent.Direction.OUTGOING
	weak.percent = -25
	_add_status("weak", "弱体", D, ROUND, 999, [weak], "与える攻撃ダメージが 25% 減る。残り {stacks} ラウンド。")
	_add_status("poison", "毒", D, NONE, 999, [DamageOverTime.new()],
		"プレイヤーのターン終了時に、ブロックを無視して {stacks} ダメージを受け、毒が 1 減る。")
	_add_status("barricade", "バリケード", B, NONE, 1, [KeepBlock.new()], "ブロックがターン開始時に消えなくなる。")
	_add_status("thorns", "トゲ", B, NONE, 999, [Retaliate.new()], "攻撃を受けたとき、攻撃者に {stacks} ダメージを与える。")
	_add_status("artifact", "アーティファクト", B, NONE, 99, [NegateDebuff.new()], "次に付与されるデバフを {stacks} 回打ち消す。")
	_add_status("revive", "起死回生", B, NONE, 9, [CheatDeath.new()],
		"致死ダメージを受けたとき、HP 1 で踏みとどまり HP を 10 回復する。1 回ごとに 1 減る（残り {stacks}）。")
	_add_status("regenerate", "再生", B, NONE, 999, [HealOverTime.new()],
		"プレイヤーのターン終了時に HP を {stacks} 回復し、再生が 1 減る。")
	var demon := GrantStatusOnTurnStart.new()
	demon.status = _statuses["strength"]
	demon.per_stack = 2
	_add_status("demon_form", "悪魔化", B, NONE, 9, [demon], "ターン開始時に、悪魔化 1 につき筋力を 2 得る（悪魔化 {stacks}）。")


func _add_status(id: String, name: String, polarity: StatusData.Polarity, decay: StatusData.Decay,
		max_stacks: int, behaviors: Array, text: String) -> void:
	var s := StatusData.new()
	s.id = id
	s.name = name
	s.polarity = polarity
	s.decay = decay
	s.max_stacks = max_stacks
	s.behaviors.assign(behaviors)
	s.text = text
	_statuses[id] = s
	_register(s, "statuses/%s.tres" % id)


func _build_keywords() -> void:
	_add_keyword("exhaust", KeywordData.Kind.EXHAUST, "廃棄",
		"プレイ後は捨て札ではなく廃棄札に入る。この戦闘の残りの間は二度と引かない。")
	_add_keyword("retain", KeywordData.Kind.RETAIN, "保留", "ターン終了時に捨てられず、手札に残って次のターンへ持ち越す。")
	_add_keyword("innate", KeywordData.Kind.INNATE, "天賦", "戦闘開始の第 1 ターンに必ず初期手札に入る。")
	_add_keyword("ethereal", KeywordData.Kind.ETHEREAL, "エセリアル",
		"ターン終了時にまだ手札にあれば、捨てられるのではなくそのまま廃棄される。")
	_add_keyword("unplayable", KeywordData.Kind.UNPLAYABLE, "プレイ不可",
		"自分からはプレイできない。他の効果で捨てる・廃棄するしかない。")


func _add_keyword(id: String, kind: KeywordData.Kind, name: String, text: String) -> void:
	var k := KeywordData.new()
	k.id = id
	k.kind = kind
	k.name = name
	k.text = text
	_register(k, "keywords/%s.tres" % id)


# —— カード ——

func _build_cards() -> void:
	var A := CardData.Type.ATTACK
	var S := CardData.Type.SKILL
	var P := CardData.Type.POWER
	var BASIC := CardData.Rarity.STARTER
	var C := CardData.Rarity.COMMON
	var U := CardData.Rarity.UNCOMMON
	var R := CardData.Rarity.RARE
	var HAND := Pile.Id.HAND
	var CH := ChooseCardsEffect.Action

	# ステータスカード / 呪い（他のカードや敵が参照するので先に作る）。
	_add_card("wound", "傷", UNPLAYABLE, CardData.Type.STATUS, CardData.Rarity.SPECIAL, "", [])
	_add_card("dazed", "めまい", UNPLAYABLE, CardData.Type.STATUS, CardData.Rarity.SPECIAL, "", [], {kw = ETH})
	_add_card("slimed", "粘液", 1, CardData.Type.STATUS, CardData.Rarity.SPECIAL, "", [], {kw = EXH})
	_add_card("burn", "火傷", UNPLAYABLE, CardData.Type.STATUS, CardData.Rarity.SPECIAL,
		"ターン終了時に手札にあれば HP を 2 失う。", [], {end_of_turn = [_lose(2)]})
	_add_card("injury", "負傷", UNPLAYABLE, CardData.Type.CURSE, CardData.Rarity.SPECIAL, "", [])
	_add_card("doubt", "疑念", UNPLAYABLE, CardData.Type.CURSE, CardData.Rarity.SPECIAL,
		"ターン終了時に手札にあれば弱体を 1 得る。", [], {end_of_turn = [_apply("weak", 1, _t_self)]})

	# —— A.1 基本カードプール ——
	var dmg_text := "{damage} ダメージを与える。"
	var block_text := "ブロックを {block} 得る。"
	_with_upgrade("strike", "ストライク", 1, A, BASIC, dmg_text, [_dmg(6, _t_chosen)], [_dmg(9, _t_chosen)])
	_with_upgrade("defend", "防御", 1, S, BASIC, block_text, [_block(5)], [_block(8)])
	var bash_text := "{damage} ダメージを与え、脆弱を {vulnerable} 付与する。"
	_with_upgrade("bash", "強打", 2, A, BASIC, bash_text,
		[_dmg(8, _t_chosen), _apply("vulnerable", 2, _t_chosen, &"vulnerable")],
		[_dmg(10, _t_chosen), _apply("vulnerable", 3, _t_chosen, &"vulnerable")])
	_with_upgrade("cleave", "なぎ払い", 1, A, C, "敵全体に {damage} ダメージを与える。",
		[_dmg(8, _t_all)], [_dmg(11, _t_all)])
	_with_upgrade("iron_wave", "アイアンウェーブ", 1, A, C, "ブロックを {block} 得て、{damage} ダメージを与える。",
		[_block(5), _dmg(5, _t_chosen)], [_block(7), _dmg(7, _t_chosen)])
	_with_upgrade("shrug_it_off", "受け流し", 1, S, C, "ブロックを {block} 得て、1 枚引く。",
		[_block(8), _draw(1)], [_block(11), _draw(1)])
	_add_card("poison_stab", "毒突き", 1, A, C, "{damage} ダメージを与え、毒を {poison} 付与する。",
		[_dmg(5, _t_chosen), _apply("poison", 3, _t_chosen, &"poison")])
	_add_card("finisher", "フィニッシャー", 2, A, C, "{damage} ダメージを与える。対象の HP が 50% 未満なら +10。",
		[_dmg(_if(_hp_below(ValueSource.On.TARGET, 50), 20, 10), _t_chosen)])
	_with_upgrade("spare_blade", "予備の刃", 0, A, C, dmg_text, [_dmg(5, _t_chosen)], [_dmg(8, _t_chosen)], {kw = RET})
	_with_upgrade("composure", "平静", 1, S, C, block_text, [_block(8)], [_block(11)], {kw = RET})
	_add_card("opening", "先手", 0, S, C, "2 枚引く。", [_draw(2)], {kw = INN | EXH})
	_with_upgrade("flurry", "疾風連撃", 1, A, C, "{damage} ダメージを 3 回与える。",
		[_dmg(4, _t_chosen, &"damage", 3)], [_dmg(4, _t_chosen, &"damage", 5)],
		{}, "{damage} ダメージを 5 回与える。")
	_with_upgrade("sift", "選別", 1, S, C, "手札を 1 枚選んで捨て、2 枚引く。",
		[_choose(HAND, CH.DISCARD, 1), _draw(2)], [_choose(HAND, CH.DISCARD, 1), _draw(3)],
		{}, "手札を 1 枚選んで捨て、3 枚引く。")
	_add_card("purge", "浄化", 0, S, C, "手札を 1 枚選んで廃棄する。", [_choose(HAND, CH.EXHAUST, 1)], {kw = EXH})
	_add_card("hold_fast", "保持", 0, S, C, "手札を 1 枚選んでこのターン保留し、1 枚引く。",
		[_choose(HAND, CH.RETAIN, 1), _draw(1)])
	_add_card("stash", "隠し札", 0, S, C, "手札を 1 枚選んで山札の一番上に戻し、1 枚引く。",
		[_choose(HAND, CH.TO_DRAW_TOP, 1), _draw(1)])
	_add_card("whirlwind", "旋風刃", COST_X, A, U, "敵全体に {damage} ダメージを X 回与える。",
		[_dmg(5, _t_all, &"damage", XValue.new())])
	_add_card("bladedance", "剣の舞", 1, A, U, "ランダムな敵に {damage} ダメージを与える。これを手札の枚数回（最低 1 回）繰り返す。",
		[_repeat(_hand_count(0, 1), [_dmg(4, _t_random)])])
	_add_card("body_slam", "ボディスラム", 1, A, U, "現在のブロックと同じ {damage} ダメージを与える。",
		[_dmg(_block_of(ValueSource.On.SELF), _t_chosen)])
	_add_card("inflame", "発火", 1, P, U, "筋力を {strength} 得る。", [_apply("strength", 2, _t_self, &"strength")])
	_add_card("field_dressing", "応急手当", 1, S, U, "再生を {regenerate} 得る。",
		[_apply("regenerate", 5, _t_self, &"regenerate")])
	_add_card("ward", "守護の呪文", 1, S, U, "アーティファクトを {artifact} 得る。",
		[_apply("artifact", 2, _t_self, &"artifact")], {kw = EXH})
	_with_upgrade("ambush", "待ち伏せ", 2, A, U, "{damage} ダメージを与える（手札 1 枚につき 3）。",
		[_dmg(_sc(0, 3, _hand_count()), _t_chosen)], [_dmg(_sc(0, 5, _hand_count()), _t_chosen)],
		{kw = RET}, "{damage} ダメージを与える（手札 1 枚につき 5）。")
	_add_card("vigil", "不寝番", 2, S, U, block_text, [_block(12)], {kw = INN})
	_with_upgrade("phantom_blade", "幻影の刃", 0, A, U, dmg_text, [_dmg(12, _t_chosen)], [_dmg(16, _t_chosen)], {kw = ETH})
	_add_card("fleeting_insight", "刹那の閃き", 0, S, U, "3 枚引き、エネルギーを 1 得る。",
		[_draw(3), _energy(1)], {kw = ETH | EXH})
	_add_card("last_stand", "背水の陣", 2, A, U, "{damage} ダメージを与える。自分の HP が 50% 未満なら +10。",
		[_dmg(_if(_hp_below(ValueSource.On.SELF, 50), 20, 10), _t_chosen)])
	_add_card("follow_up", "追撃", 1, A, U,
		"{damage} ダメージを与える。直前のカードがアタックなら 1 枚引く。そうでなければブロックを 3 得る。",
		[_dmg(7, _t_chosen), _branch(_last_type(ATK), [_draw(1)], [_block(3, &"")])])
	_add_card("wild_gamble", "一か八か", 1, S, U, "ランダムに 1 つ：ブロックを 8 得る / 2 枚引く / エネルギーを 2 得る。",
		[_random([[40, [_block(8, &"")]], [40, [_draw(2)]], [20, [_energy(2)]]])])
	_add_card("gather_strength", "力を溜める", 0, S, U, "次のターン開始時に、筋力を 2 とブロックを 8 得る。",
		[_defer(DeferEffect.Timing.START_OF_NEXT_TURN, [_apply("strength", 2, _t_self), _block(8, &"")])], {kw = EXH})
	_add_card("transcribe", "写し取り", 1, S, U, "手札を 1 枚選んで複製する（一時）。", [_choose(HAND, CH.DUPLICATE, 1)])
	_add_card("recall", "回収", 2, S, U, "捨て札から 1 枚選んで手札に加える。", [_choose(Pile.Id.DISCARD, CH.TO_HAND, 1)])
	_add_card("adrenaline", "アドレナリン", 0, S, R, "2 枚引き、エネルギーを 1 得る。", [_draw(2), _energy(1)], {kw = EXH})
	_add_card("barricade", "バリケード", 3, P, R, "ブロックがターン開始時に消えなくなる。", [_apply("barricade", 1, _t_self)])
	_add_card("offering", "供物", 0, S, R, "HP を 6 失い、エネルギーを 2 得て、3 枚引く。",
		[_lose(6), _energy(2), _draw(3)], {kw = EXH})
	_add_card("demon_form", "悪魔化", 3, P, R, "毎ターン開始時に筋力を 2 得る。", [_apply("demon_form", 1, _t_self)])
	_add_card("reinforcements", "増援", 1, S, R, "ストライク（一時）を 2 枚手札に加え、1 枚引く。",
		[_create("strike", Pile.Place.HAND, 2), _draw(1)], {kw = EXH})
	_add_card("battle_fervor", "闘志", 1, P, R, "筋力を {strength} 得る。",
		[_apply("strength", 2, _t_self, &"strength")], {kw = INN})
	_add_card("time_bomb", "時限爆弾", 1, S, R, "このターンの終了時に、敵全体に {damage} ダメージを与える。",
		[_defer(DeferEffect.Timing.END_OF_THIS_TURN, [_dmg(14, _t_all)])])
	_add_card("burden_of_proof", "立証責任", 1, S, R, "ブロックを {block} 得る。ターン終了時に手札にあれば HP を 2 失う。",
		[_block(14)], {kw = RET, end_of_turn = [_lose(2)]})

	# —— A.2 拡張カードプール ——
	var poison_on_target := _stacks("poison", ValueSource.On.TARGET)
	_with_upgrade("crescent_slash", "三日月斬り", 1, A, U, bash_text,
		[_dmg(8, _t_chosen), _apply("vulnerable", 1, _t_chosen, &"vulnerable")],
		[_dmg(11, _t_chosen), _apply("vulnerable", 2, _t_chosen, &"vulnerable")])
	_add_card("tempest_dance", "嵐の舞", 2, S, R, "ランダムな敵に {damage} ダメージを与え、ブロックを {block} 得る。これを 2 回繰り返す。",
		[_repeat(2, [_dmg(5, _t_random), _block(3)])])
	_with_upgrade("zealous_strike", "狂信の一撃", 1, A, C, "{damage} ダメージを与える（自分の筋力 1 につき +3）。",
		[_dmg(_sc(4, 3, _stacks("strength", ValueSource.On.SELF)), _t_chosen)],
		[_dmg(_sc(6, 3, _stacks("strength", ValueSource.On.SELF)), _t_chosen)])
	_add_card("overload", "オーバーロード", COST_X, A, R, "敵全体に {damage} ダメージを与える（5×X）。",
		[_dmg(_sc(0, 5, XValue.new()), _t_all)], {kw = EXH})
	_add_card("desperate_gambit", "決死の賭け", 1, S, U,
		"HP が 50% 未満なら 2 枚引き、エネルギーを 1 得る。そうでなければ「傷」を 1 枚捨て札に入れる。",
		[_branch(_hp_below(ValueSource.On.SELF, 50), [_draw(2), _energy(1)], [_create("wound", Pile.Place.DISCARD, 1)])])
	_add_card("blood_pact", "血の契約", 0, S, C, "HP を 5 失い、エネルギーを 2 得る。", [_lose(5), _energy(2)])
	_add_card("pain_conversion", "痛覚転化", 1, A, C, "HP を 3 失い、{damage} ダメージを与える。", [_lose(3), _dmg(13, _t_chosen)])
	_add_card("last_ditch", "捨て身の一撃", 1, A, C, "{damage} ダメージを与える（失った HP 1 につき +1。最大 26）。",
		[_dmg(_sc(5, 1, _missing_hp(), 26), _t_chosen)])
	var siphon_heal := HealEffect.new()
	siphon_heal.amount = _stat(ResolveStatValue.Stat.DAMAGE_DEALT)
	_add_card("siphon", "吸収", 2, A, U, "{damage} ダメージを与え、実際に与えたダメージと同じだけ HP を回復する。",
		[_dmg(9, _t_chosen), siphon_heal])
	_add_card("blood_feast", "血の宴", 2, S, U, "HP を 10 失い、3 枚引き、このターン手札のコストを 1 下げる。",
		[_lose(10), _draw(3), _cost(ModifyCostEffect.Scope.HAND, -1, true)])
	_add_card("sacrificial_edge", "生贄の刃", 1, A, U, "{damage} ダメージを与える（自分の HP が 50% 未満なら 15）。",
		[_dmg(_if(_hp_below(ValueSource.On.SELF, 50), 15, 6), _t_chosen)])
	_add_card("devour_misfortune", "厄喰らい", 1, A, U, "手札のステータスカードと呪いをすべて廃棄し、1 枚につき敵全体に 7 ダメージを与える。",
		[_exhaust_all(STATUS_OR_CURSE), _dmg(_sc(0, 7, _stat(ResolveStatValue.Stat.CARDS_AFFECTED)), _t_all, &"")])
	_add_card("dark_bargain", "闇の取引", 0, S, C, "「傷」を 2 枚捨て札に入れ、エネルギーを 2 得る。",
		[_create("wound", Pile.Place.DISCARD, 2), _energy(2)])
	_add_card("purge_ritual", "浄化の儀", 1, S, C, "手札のステータスカードか呪いを 1 枚選んで廃棄し、2 枚引く。",
		[_choose(HAND, CH.EXHAUST, 1, true, STATUS_OR_CURSE), _draw(2)])
	_add_card("sufferer", "受難者", 1, S, C, "ブロックを {block} 得る（手札のステータスカード / 呪い 1 枚につき +5）。",
		[_block(_sc(4, 5, _hand_count(STATUS_OR_CURSE)))])
	_add_card("curse_eater", "心喰い", 1, A, C, "{damage} ダメージを与える（手札にステータスカードか呪いがあれば 16）。",
		[_dmg(_if(_hand_has(STATUS_OR_CURSE), 16, 8), _t_chosen)])
	_add_card("grim_resolve", "冷徹な決意", 2, A, U, "敵全体に {damage} ダメージを与える（手札のステータスカード / 呪い 1 枚につき +4）。",
		[_dmg(_sc(8, 4, _hand_count(STATUS_OR_CURSE)), _t_all)])
	_add_card("vigilance", "構え", 1, S, C, "ブロックを {block} 得る（保留ターン 1 につき +3）。",
		[_block(_sc(4, 3, CardRetainedTurnsValue.new()))], {kw = RET})
	_add_card("patient_strike", "溜め斬り", 1, A, C, "{damage} ダメージを与える（保留ターン 1 につき +4）。",
		[_dmg(_sc(6, 4, CardRetainedTurnsValue.new()), _t_chosen)], {kw = RET})
	_add_card("meditation", "瞑想", 1, S, U, "{draw} 枚引く（保留ターン 1 につき +1。最大 4）。",
		[_draw(_sc(1, 1, CardRetainedTurnsValue.new(), 4), &"draw")], {kw = RET})
	_add_card("killing_patience", "好機を待つ", 0, A, U, "{damage} ダメージを与える（保留ターン 1 につき +7）。",
		[_dmg(_sc(5, 7, CardRetainedTurnsValue.new()), _t_chosen)], {kw = RET | EXH})
	_add_card("hold_the_line", "死守", 1, S, C, "ブロックを {block} 得る。手札を最大 3 枚選び、このターンの終了時に保留する。",
		[_block(6), _choose(HAND, CH.RETAIN, 3, true)])
	_add_card("honed_edge", "研ぎ澄まし", 1, A, U, "{damage} ダメージを与える。この戦闘中、プレイするたびにダメージ +3。",
		[_dmg(_sc(5, 1, CardGrowthValue.new()), _t_chosen), _grow(3)])
	_add_card("tremor", "戦慄", 1, S, C, "ブロックを {block} 得る。捨てられた時：ランダムな敵に 8 ダメージを与える。",
		[_block(5)], {on_discard = [_dmg(8, _t_random, &"")]})
	_add_card("sprint", "疾走", 1, S, C, "2 枚引く。捨てられた時：1 枚引く。", [_draw(2)], {on_discard = [_draw(1)]})
	_add_card("hoard", "溜め込み", 1, S, C, "手札を 2 枚選んで捨て、3 枚引く。",
		[_choose(HAND, CH.DISCARD, 2, true), _draw(3)])
	_add_card("cast_off", "投げ捨て", 1, A, U, "手札をすべて捨て、1 枚につき敵全体に 4 ダメージを与える。",
		[_discard_all(), _dmg(_sc(0, 4, _stat(ResolveStatValue.Stat.CARDS_AFFECTED)), _t_all, &"")])
	_add_card("scavenger", "漁る者", 0, S, C, "手札を 1 枚選んで捨て、捨てた 1 枚につきブロックを 8 得る。",
		[_choose(HAND, CH.DISCARD, 1, true), _block(_sc(0, 8, _stat(ResolveStatValue.Stat.CARDS_AFFECTED)), &"")])
	_add_card("from_the_ashes", "灰からの再起", 1, S, U, "捨て札から最大 2 枚選んで手札に加える。",
		[_choose(Pile.Id.DISCARD, CH.TO_HAND, 2, true)])
	_add_card("ember", "残り火", 1, S, C, "ブロックを {block} 得る。廃棄された時：エネルギーを 1 得る。",
		[_block(6)], {kw = EXH, on_exhaust = [_energy(1)]})
	_add_card("immolate", "焼却", 1, A, U, "{damage} ダメージを与える。廃棄された時：敵全体に 7 ダメージを与える。",
		[_dmg(8, _t_chosen)], {kw = EXH, on_exhaust = [_dmg(7, _t_all, &"")]})
	_add_card("recast", "鋳直し", 1, S, U, "廃棄札から 1 枚選んで手札に加える。", [_choose(Pile.Id.EXHAUST, CH.TO_HAND, 1)])
	_add_card("entropy", "エントロピー", 1, A, C, "{damage} ダメージを与える（廃棄札 1 枚につき +2）。",
		[_dmg(_sc(5, 2, _pile(Pile.Id.EXHAUST)), _t_chosen)])
	var affected := _stat(ResolveStatValue.Stat.CARDS_AFFECTED)
	_add_card("nirvana", "涅槃", 2, S, R, "手札をすべて廃棄し、1 枚につき 1 枚引いてブロックを 3 得る。",
		[_exhaust_all(), _draw(_sc(0, 1, affected)), _block(_sc(0, 3, affected), &"")])
	_add_card("purifying_flame", "浄炎", 1, S, C, "手札を 1 枚選んで廃棄し、廃棄札 1 枚につきブロックを 2 得る。",
		[_choose(HAND, CH.EXHAUST, 1), _block(_sc(0, 2, _pile(Pile.Id.EXHAUST)), &"")])
	_add_card("prelude", "前奏", 0, A, C, "{damage} ダメージを与える（直前にプレイしたのがスキルなら 11）。",
		[_dmg(_if(_last_type(SKL), 11, 4), _t_chosen)])
	_add_card("turnabout", "転機", 1, S, C, "ブロックを {block} 得る。直前のカードがアタックなら、さらにブロックを 4 得て 1 枚引く。",
		[_block(5), _branch(_last_type(ATK), [_block(4, &""), _draw(1)])])
	_add_card("crescendo", "クレッシェンド", 2, A, U, "敵全体に {damage} ダメージを与える（このターンにプレイしたカード 1 枚につき 4。これを含む）。",
		[_dmg(_sc(0, 4, _played(0)), _t_all)])
	_add_card("finale", "フィナーレ", 1, A, U, "{damage} ダメージを与える（このターン 3 枚目以降のアタックなら 22）。",
		[_dmg(_if(_cmp(_played(ATK), CompareCondition.Op.GREATER_EQUAL, 3), 22, 6), _t_chosen)])
	_add_card("opening_move", "先制", 0, A, C, "{damage} ダメージを与える（このターン最初のカードなら 12）。",
		[_dmg(_if(_cmp(_played(0), CompareCondition.Op.LESS_EQUAL, 1), 12, 4), _t_chosen)])
	_add_card("counterpoint", "対位法", 1, A, C, "敵全体に {damage} ダメージを与える（直前のカードがアタックでなければ 10）。",
		[_dmg(_if(_last_type(ATK), 5, 10), _t_all)])
	_add_card("catalyst", "触媒", 1, S, U, "対象の毒を 2 倍にする。", [_apply("poison", poison_on_target, _t_chosen)])
	var infection := SpreadStatusEffect.new()
	infection.status = _statuses["poison"]
	infection.target = _t_chosen
	infection.spread_to = _t_others
	infection.percent = 50
	_add_card("infection", "感染", 1, S, U, "対象の毒の半分を、他のすべての敵に付与する。", [infection])
	_add_card("detonate", "起爆", 2, A, R, "対象の毒をすべて消費し、1 スタックにつき 3 ダメージを与える。",
		[_consume("poison", true, 0), _dmg(_sc(0, 3, _stat(ResolveStatValue.Stat.CONSUMED_STACKS)), _t_chosen, &"")])
	# 毒突きと同じ効果だったので差別化した（M1 決定事項 B6）。
	_add_card("corrode", "腐食", 1, A, C, "{damage} ダメージを与え、毒を {poison} 付与する。",
		[_dmg(3, _t_chosen), _apply("poison", 5, _t_chosen, &"poison")])
	_add_card("plague", "疫病", 2, S, U, "敵全体に毒を {poison} 付与する。", [_apply("poison", 4, _t_all, &"poison")])
	_add_card("toxic_burst", "毒爆", 1, A, C, "対象の毒を最大 3 消費し、1 スタックにつき 4 ダメージを与える。",
		[_consume("poison", false, 3), _dmg(_sc(0, 4, _stat(ResolveStatValue.Stat.CONSUMED_STACKS)), _t_chosen, &"")])


## カードを作って登録する。cost に COST_X / UNPLAYABLE を渡せる。
## opt: kw（キーワードのビット）、up（アップグレード版）、on_draw / on_discard / on_exhaust / end_of_turn、folder。
func _add_card(id: String, name: String, cost: int, type: CardData.Type, rarity: CardData.Rarity,
		text: String, on_play: Array, opt: Dictionary = {}) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = name
	c.type = type
	c.rarity = rarity
	c.text = text
	if cost == COST_X:
		c.cost_mode = CardData.CostMode.X
		c.cost = 0
	elif cost == UNPLAYABLE:
		c.cost_mode = CardData.CostMode.UNPLAYABLE
		c.cost = 0
	else:
		c.cost = cost
	c.keywords = opt.get("kw", 0)
	c.upgraded = opt.get("up", null)
	c.on_play.assign(on_play)
	c.on_draw.assign(opt.get("on_draw", []))
	c.on_discard.assign(opt.get("on_discard", []))
	c.on_exhaust.assign(opt.get("on_exhaust", []))
	c.end_of_turn_in_hand.assign(opt.get("end_of_turn", []))
	CardArt.apply(c)
	var targets: Array[Resource] = []
	_collect_targets(c.on_play, targets)
	c.aim = CardData.Aim.ENEMY if targets.has(_t_chosen) else CardData.Aim.NONE
	var folder: String = opt.get("folder", _card_folder(type, rarity))
	_cards[id] = c
	_register(c, "cards/%s/%s.tres" % [folder, id])
	return c


## アップグレード版（id_plus、名前 +、レアリティ SPECIAL）と基本版を作る。up_text が空なら基本版と同じテキスト。
func _with_upgrade(id: String, name: String, cost: int, type: CardData.Type, rarity: CardData.Rarity,
		text: String, on_play: Array, up_on_play: Array, opt: Dictionary = {}, up_text: String = "") -> CardData:
	var folder := _card_folder(type, rarity)
	var up_opt := opt.duplicate()
	up_opt["folder"] = folder
	var up := _add_card(id + "_plus", name + "+", cost, type, CardData.Rarity.SPECIAL,
		up_text if not up_text.is_empty() else text, up_on_play, up_opt)
	var base_opt := opt.duplicate()
	base_opt["up"] = up
	return _add_card(id, name, cost, type, rarity, text, on_play, base_opt)


func _card_folder(type: CardData.Type, rarity: CardData.Rarity) -> String:
	if type == CardData.Type.STATUS:
		return "status"
	if type == CardData.Type.CURSE:
		return "curse"
	return ["starter", "common", "uncommon", "rare", "special"][rarity]


func _collect_targets(value: Variant, out: Array[Resource]) -> void:
	if value is TargetRule:
		out.append(value)
	elif value is Resource:
		var res := value as Resource
		if _paths.has(res):
			return  # 別のコンテンツ（CreateCardEffect.card など）の中までは見ない
		for prop in res.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_collect_targets(res.get(prop["name"]), out)
	elif value is Array:
		for item: Variant in value:
			_collect_targets(item, out)


# —— ポーション ——

func _build_potions() -> void:
	var C := PotionData.Rarity.COMMON
	var U := PotionData.Rarity.UNCOMMON
	var R := PotionData.Rarity.RARE
	var heal := HealEffect.new()
	heal.amount = _v(18)
	heal.label = &"heal"
	_add_potion("healing", "回復ポーション", C, "HP を {heal} 回復する。", [heal])
	_add_potion("block", "鉄壁ポーション", C, "ブロックを {block} 得る。", [_block(12)])
	_add_potion("energy", "活力ポーション", C, "エネルギーを 2 得る。", [_energy(2)])
	_add_potion("draw", "閃きポーション", C, "3 枚引く。", [_draw(3)])
	# ポーションのダメージは筋力などの補正を受けない（STATUS 種別。M1 決定事項）。
	_add_potion("fire", "炎のポーション", C, "敵 1 体に {damage} ダメージを与える。",
		[_dmg(20, _t_chosen, &"damage", null, DamageEffect.Kind.STATUS)])
	_add_potion("weak", "弱体ポーション", U, "弱体を {weak} 付与する。", [_apply("weak", 3, _t_chosen, &"weak")])
	_add_potion("poison", "猛毒ポーション", U, "毒を {poison} 付与する。", [_apply("poison", 6, _t_chosen, &"poison")])
	_add_potion("strength", "筋力ポーション", U, "筋力を {strength} 得る。", [_apply("strength", 2, _t_self, &"strength")])
	_add_potion("cleanse", "澄明ポーション", R, "手札を最大 2 枚選んで廃棄し、その後 3 枚引く。",
		[_choose(Pile.Id.HAND, ChooseCardsEffect.Action.EXHAUST, 2, true), _draw(3)])
	_add_potion("fracture", "砕裂ポーション", R, "敵全体に {damage} ダメージを 3 回与える。",
		[_dmg(5, _t_all, &"damage", 3, DamageEffect.Kind.STATUS)])


func _add_potion(id: String, name: String, rarity: PotionData.Rarity, text: String, effects: Array) -> void:
	var p := PotionData.new()
	p.id = id
	p.name = name
	p.rarity = rarity
	p.text = text
	p.effects.assign(effects)
	var targets: Array[Resource] = []
	_collect_targets(p.effects, targets)
	p.aim = CardData.Aim.ENEMY if targets.has(_t_chosen) else CardData.Aim.NONE
	_register(p, "potions/%s.tres" % id)


# —— レリック ——

func _build_relics() -> void:
	var RR := RelicData.Rarity
	_add_relic("burning_blood", "燃える血", RR.STARTER, "戦闘勝利後に HP を 6 回復する。", _victory(6, 0))
	_add_relic("vajra", "金剛杵", RR.COMMON, "各戦闘の開始時に筋力を 1 得る。", _grant_at_start("strength", 1))
	_add_relic("anchor", "錨", RR.COMMON, "各戦闘の第 1 ターンにブロックを 10 得る。", _start_resources(10, 0))
	_add_relic("blood_vial", "血の小瓶", RR.COMMON, "各戦闘の開始時に HP を 2 回復する。", _start_resources(0, 2))
	_add_relic("bronze_scales", "青銅の鱗", RR.COMMON, "各戦闘の開始時にトゲを 3 得る。", _grant_at_start("thorns", 3))
	_add_relic("bag_of_preparation", "準備袋", RR.UNCOMMON, "各戦闘の第 1 ターンに追加で 2 枚引く。", _turn_resources(0, 2, true))
	_add_relic("lantern", "提灯", RR.UNCOMMON, "各戦闘の第 1 ターンに追加でエネルギーを 1 得る。", _turn_resources(1, 0, true))
	_add_relic("pen_nib", "ペン先", RR.UNCOMMON, "毎ターン最初にプレイするアタックのコストが 1 下がる。", FirstCardOfTypeCostDown.new())
	_add_relic("artifact_totem", "アーティファクトトーテム", RR.UNCOMMON, "各戦闘の開始時にアーティファクトを 1 得る。",
		_grant_at_start("artifact", 1))
	_add_relic("meditation_beads", "瞑想の数珠", RR.UNCOMMON, "スキルを 3 枚プレイするごとに HP を 2 回復する。", EveryNCardsHeal.new())
	_add_relic("echo_charm", "反響の護符", RR.RARE, "毎ターン最初にプレイするアタックがもう一度解決される。", FirstCardOfTypeEcho.new())
	_add_relic("recycler", "リサイクラー", RR.RARE, "プレイしたスキルは捨て札ではなく山札にシャッフルされる。", RedirectCardDestination.new())
	_add_relic("lizard_tail", "トカゲの尻尾", RR.RARE, "各戦闘で最初に致死ダメージを受けたとき、HP 1 で踏みとどまり HP を 10 回復する。",
		_grant_at_start("revive", 1))
	_add_relic("black_star", "黒い星", RR.BOSS, "毎ターン追加でエネルギーを 1 得る。", _turn_resources(1, 0, false))
	_add_relic("philosophers_stone", "賢者の石", RR.BOSS, "毎ターン追加で 1 枚引く。", _turn_resources(0, 1, false))
	var toolbox := _add_relic("toolbox", "道具箱", RR.SHOP, "戦闘勝利後に追加で 12 ゴールドを得る。", _victory(0, 12))
	toolbox.shop_price = 180


func _add_relic(id: String, name: String, rarity: RelicData.Rarity, text: String, behavior: CombatBehavior) -> RelicData:
	var r := RelicData.new()
	r.id = id
	r.name = name
	r.rarity = rarity
	r.text = text
	r.behaviors.assign([behavior])
	_relics[id] = r
	_register(r, "relics/%s.tres" % id)
	return r


func _victory(heal: int, gold: int) -> VictoryRewards:
	var b := VictoryRewards.new()
	b.heal = heal
	b.gold = gold
	return b


func _grant_at_start(status_id: String, stacks: int) -> GrantStatusOnCombatStart:
	var b := GrantStatusOnCombatStart.new()
	b.status = _statuses[status_id]
	b.stacks = stacks
	return b


func _start_resources(block: int, heal: int) -> CombatStartResources:
	var b := CombatStartResources.new()
	b.block = block
	b.heal = heal
	return b


func _turn_resources(energy: int, draw: int, first_turn_only: bool) -> TurnResources:
	var b := TurnResources.new()
	b.energy = energy
	b.draw = draw
	b.first_turn_only = first_turn_only
	return b


# —— 敵 ——

func _build_enemies() -> void:
	var N := EnemyData.Rank.NORMAL

	_add_enemy("slime", "骸骨の毒刃使い", N, 10, 14, [
		_move("bite", "刺突", [_dmg(5, _t_chosen)]),
		_move("corrode", "毒刃", [_apply("weak", 1, _t_chosen)]),
		_move("spit", "腐液投げ", [_create("slimed", Pile.Place.DISCARD, 2)]),
	], _ai(["bite", "bite", "corrode", "spit"], true))

	_add_enemy("jawworm", "骸骨戦士", N, 40, 44, [
		_move("chomp", "大斧の一撃", [_dmg(11, _t_chosen)], {weight = 45, max_in_a_row = 2}),
		_move("thrash", "盾打ち", [_dmg(7, _t_chosen), _block(5, &"")], {weight = 30, max_in_a_row = 1}),
		_move("bellow", "骨の構え", [_block(6, &""), _apply("strength", 3, _t_self)], {weight = 25, max_in_a_row = 1}),
	], _ai(["chomp"]))

	_add_enemy("louse", "スケルトン兵", N, 10, 15, [
		_move("bite", "斬りつけ", [_dmg(6, _t_chosen)], {weight = 75}),
		_move("curl", "身構え", [_block(6, &"")],
			{weight = 25, max_in_a_row = 1, bonus_weight = 35, bonus_when = _hp_below(ValueSource.On.SELF, 50)}),
		_move("dust", "骨粉", [_create("dazed", Pile.Place.DRAW_TOP, 1)], {weight = 20, max_in_a_row = 1}),
	], _ai([]))

	_add_enemy("cultist", "骸骨の祈祷師", N, 48, 54, [
		_move("ritual", "儀式", [_apply("strength", 3, _t_self)], {max_uses = 1}),
		_move("lash", "呪弾", [_dmg(6, _t_chosen)], {weight = 100}),
	], _ai(["ritual"]))

	_add_enemy("gremlin_nob", "骨の巨像", EnemyData.Rank.ELITE, 82, 86, [
		_move("bellow", "雄叫び", [_apply("strength", 2, _t_self)], {max_uses = 1}),
		_move("skull_bash", "粉砕", [_dmg(14, _t_chosen)], {weight = 66, max_in_a_row = 2}),
		_move("stomp", "踏み鳴らし", [_dmg(8, _t_chosen), _apply("vulnerable", 2, _t_chosen)], {weight = 34, max_in_a_row = 1}),
	], _ai(["bellow"]))

	var guardian_ai := _ai([])
	guardian_ai.phase_thresholds = PackedInt32Array([50])
	var cleanse := RemoveStatusesEffect.new()
	cleanse.target = _t_self
	guardian_ai.phase_change_effects.assign([cleanse, _apply("strength", 5, _t_self)])
	var PH1 := 1
	var PH2 := 2
	_add_enemy("guardian", "死霊術師", EnemyData.Rank.BOSS, 240, 240, [
		_move("charge", "魔力集中", [_apply("strength", 2, _t_self)], {weight = 20, phases = PH1}),
		_move("slam", "冥炎", [_dmg(16, _t_chosen)], {weight = 40, max_in_a_row = 2, phases = PH1}),
		_move("shield", "骨の障壁", [_block(20, &"")], {weight = 40, phases = PH1}),
		_move("fury", "死霊の乱舞", [_dmg(9, _t_chosen, &"damage", 3)], {weight = 60, phases = PH2}),
		_move("doom", "破滅", [_dmg(32, _t_chosen), _apply("weak", 2, _t_chosen)],
			{weight = 40, max_in_a_row = 1, phases = PH2, priority = 1,
			forced_when = _block_at_least(ValueSource.On.TARGET, 20)}),
	], guardian_ai, {"thorns": 3})


func _add_enemy(id: String, name: String, rank: EnemyData.Rank, hp_min: int, hp_max: int,
		moves: Array, ai: EnemyAI, statuses: Dictionary = {}) -> void:
	var e := EnemyData.new()
	e.id = id
	e.name = name
	e.rank = rank
	e.hp_min = hp_min
	e.hp_max = hp_max
	e.moves.assign(moves)
	e.ai = ai
	var start: Dictionary[StatusData, int] = {}
	for status_id: String in statuses:
		start[_statuses[status_id]] = statuses[status_id]
	e.starting_statuses = start
	_enemies[id] = e
	_register(e, "enemies/%s.tres" % id)


func _move(id: String, name: String, effects: Array, opt: Dictionary = {}) -> EnemyMove:
	var m := EnemyMove.new()
	m.id = id
	m.name = name
	m.effects.assign(effects)
	for key: String in opt:
		m.set(key, opt[key])
	return m


func _ai(opening: Array, loop: bool = false) -> ScriptedAI:
	var ai := ScriptedAI.new()
	ai.opening.assign(opening.map(func(s: String) -> StringName: return StringName(s)))
	ai.loop_opening = loop
	return ai


# —— エンカウント / イベント / アクト / 設定 ——

func _build_encounters() -> void:
	var N := EnemyData.Rank.NORMAL
	var E := EnemyData.Rank.ELITE
	# 序盤用（early）：初期デッキでも大きく削られないもの。骸骨戦士と祈祷師は序盤には出さない
	# （初期デッキでの平均被ダメがエリート並み。tests/sim/test_encounter_balance.gd で測定）。
	_add_encounter("slime", "毒刃使い", N, ["slime"], true)
	_add_encounter("double_slime", "毒刃使い 2 体", N, ["slime", "slime"], true)
	_add_encounter("jawworm", "骸骨戦士", N, ["jawworm"], true)
	_add_encounter("louse_pack", "スケルトン兵の群れ", N, ["louse", "louse", "louse"], true)
	_add_encounter("cultist", "骸骨の祈祷師", N, ["cultist"], true)
	_add_encounter("slime_and_louse", "毒刃使いとスケルトン兵", N, ["slime", "louse"], true)
	_add_encounter("worm_and_cultist", "骸骨戦士と祈祷師", N, ["jawworm", "cultist"])
	# 「混成部隊」はエリート枠だが、敵自体は通常ランク（validator は warning を出す）。
	_add_encounter("mixed", "混成部隊", E, ["jawworm", "slime"])
	_add_encounter("gremlin_nob", "骨の巨像", E, ["gremlin_nob"])
	_add_encounter("nob_and_louse", "巨像と取り巻き", E, ["gremlin_nob", "louse"])
	_add_encounter("guardian", "死霊術師", EnemyData.Rank.BOSS, ["guardian"])


func _add_encounter(id: String, name: String, rank: EnemyData.Rank, enemy_ids: Array, early: bool = false) -> void:
	var enc := EncounterData.new()
	enc.id = id
	enc.name = name
	enc.rank = rank
	enc.early = early
	enc.enemies.assign(enemy_ids.map(func(e: String) -> EnemyData: return _enemies[e]))
	enc.acts = 1
	_encounters[id] = enc
	_register(enc, "encounters/%s.tres" % id)


func _build_events() -> void:
	var leave := _option("立ち去る", [], "あなたはその場を後にした。")

	_add_event("shrine_of_blood", "血の祠", "苔むした祠に、乾いた血の跡が残っている。捧げ物を求めているようだ。", [
		_option("手のひらを切る（HP -12、ランダムな 3 枚から 1 枚を選ぶ）", [_r_hp(-12), _r_add_card_choice(3)],
			"血が石に吸い込まれ、祠の奥から何かが差し出された。"),
		leave,
	])
	_add_event("wandering_smith", "旅の鍛冶屋", "金床を背負った鍛冶屋が、道端で火を起こしている。", [
		_option("研いでもらう（50 ゴールド：カードを 1 枚アップグレード）", [_r_gold(-50), _r(UpgradeCardRunEffect.new())],
			"鍛冶屋は手際よく刃を打ち直した。",
			_r_all([_r_gold_at_least(50), HasUpgradableCardRunCondition.new()]), "ゴールドが足りないか、アップグレードできるカードがない"),
		_option("お荷物を捨てる（75 ゴールド：カードを 1 枚削除）", [_r_gold(-75), _r(RemoveCardRunEffect.new())],
			"鍛冶屋は不要なものを炉に放り込んだ。", _r_gold_at_least(75), "ゴールドが足りない"),
		_option("断る", [], "あなたは礼を言って立ち去った。"),
	])
	var win := GoldRunEffect.new()
	win.amount = 130
	var bet := RandomRunEffect.new()
	bet.percent = 50
	bet.then.assign([win])
	_add_event("gambling_ghost", "博徒の亡霊", "半透明の男がサイコロを転がしている。「一勝負どうだい？」", [
		_option("50 ゴールドを賭ける（50% で 130 ゴールドを得る）", [_r_gold(-50), bet],
			"サイコロが止まった。", _r_gold_at_least(50), "ゴールドが足りない"),
		_option("賭けない", [], "亡霊はつまらなそうに消えた。"),
	])
	var spring := BranchRunEffect.new()
	var low_hp := HpBelowPercentRunCondition.new()
	low_hp.percent = 50
	spring.when = low_hp
	var heal_missing := HealMissingPercentRunEffect.new()
	heal_missing.percent = 40
	spring.then.assign([heal_missing])
	var max_hp := MaxHpRunEffect.new()
	max_hp.amount = 5
	spring.otherwise.assign([max_hp])
	_add_event("hidden_spring", "秘められた泉", "岩の割れ目から、澄んだ水が湧き出している。", [
		_option("飲み干す（HP が 50% 未満なら失った HP の 40% を回復、そうでなければ最大 HP +5）", [spring],
			"冷たい水が体に染み渡る。"),
		_option("水筒を満たす（+25 ゴールド）", [_r_gold(25)], "あなたは水を売ることにした。"),
	])
	var battle := StartBattleRunEffect.new()
	_add_event("sleeping_guardian", "眠れる番人", "鎧の番人が宝の山の前で眠っている。", [
		_option("こっそり金貨を取る（+90 ゴールド）", [_r_gold(90)], "番人は目を覚まさなかった。"),
		_option("包みを開ける（レリックを 1 つ得て、戦闘に入る）", [_r(GainRelicRunEffect.new()), battle],
			"番人が目を覚ました！"),
		_option("迂回する", [], "あなたは足音を忍ばせて通り過ぎた。"),
	])
	_add_event("abandoned_camp", "打ち捨てられた野営地", "焚き火の跡と、置き去りにされた荷物がある。", [
		_option("物資を漁る（+35 ゴールド、HP +8）", [_r_gold(35), _r_hp(8)], "役に立つものがいくつか見つかった。"),
	])
	_add_event("whispering_idol", "囁く神像", "黒い石の神像が、あなたの名を囁いている。", [
		_option("力を受け入れる（ランダムな 3 枚から 1 枚を選び、呪い「負傷」を得る）",
			[_r_add_card_choice(3), _r_add_card("injury", 1)], "力が流れ込み、同時に体のどこかが軋んだ。"),
		_option("神像を略奪する（+120 ゴールド、呪い「疑念」を 2 枚得る）",
			[_r_gold(120), _r_add_card("doubt", 2)], "囁きが頭から離れない。"),
		_option("耳をふさいで立ち去る", [], "囁きは次第に遠ざかった。"),
	])


func _add_event(id: String, title: String, body: String, options: Array) -> void:
	var ev := EventData.new()
	ev.id = id
	ev.title = title
	ev.body = body
	ev.acts = 1
	ev.options.assign(options)
	_register(ev, "events/%s.tres" % id)


## text は「名前（効果）」と書き、名前を text、括弧の中を detail に分けて入れる（括弧が無ければ名前だけ）。
func _option(text: String, effects: Array, result: String, requires: RunCondition = null, hint: String = "") -> EventOption:
	var o := EventOption.new()
	var open := text.find("（")
	if open > 0 and text.ends_with("）"):
		o.text = text.substr(0, open)
		o.detail = text.substr(open + 1, text.length() - open - 2)
	else:
		o.text = text
	o.effects.assign(effects)
	o.result_text = result
	o.requires = requires
	o.disabled_hint = hint
	return o


func _r(effect: RunEffect) -> RunEffect:
	return effect


func _r_gold(amount: int) -> GoldRunEffect:
	var e := GoldRunEffect.new()
	e.amount = amount
	return e


func _r_hp(amount: int) -> HpRunEffect:
	var e := HpRunEffect.new()
	e.amount = amount
	return e


func _r_add_card_choice(choose_from: int) -> AddCardRunEffect:
	var e := AddCardRunEffect.new()
	e.pool = AddCardRunEffect.Pool.ANY_RARITY
	e.choose_from = choose_from
	return e


func _r_add_card(card_id: String, count: int) -> AddCardRunEffect:
	var e := AddCardRunEffect.new()
	e.pool = AddCardRunEffect.Pool.FIXED
	e.card = _cards[card_id]
	e.count = count
	return e


func _r_gold_at_least(value: int) -> GoldAtLeastRunCondition:
	var c := GoldAtLeastRunCondition.new()
	c.value = value
	return c


func _r_all(conditions: Array) -> AllOfRunCondition:
	var c := AllOfRunCondition.new()
	c.conditions.assign(conditions)
	return c


func _build_acts() -> void:
	var act := ActData.new()
	act.id = "act_1"
	act.name = "第一幕：尖塔の麓"
	act.number = 1
	act.bosses.assign([_encounters["guardian"]])
	_register(act, "acts/act_1.tres")


func _build_config() -> void:
	var cfg := RunConfig.new()
	var deck: Array[CardData] = []
	for i in 5:
		deck.append(_cards["strike"])
	for i in 4:
		deck.append(_cards["defend"])
	deck.append(_cards["bash"])
	cfg.starting_deck = deck
	cfg.starting_relics.assign([_relics["burning_blood"]])
	_register(cfg, "balance/run_config.tres")


# —— ブロックの小さな組み立て関数 ——

func _v(x: Variant) -> ValueSource:
	if x is ValueSource:
		return x
	var f := FixedValue.new()
	f.value = x
	return f


func _sc(base: int, per: int, unit: ValueSource, max_value: int = 999999) -> ScaledValue:
	var s := ScaledValue.new()
	s.base = base
	s.per = per
	s.unit = unit
	s.max_value = max_value
	return s


func _if(when: Condition, then: Variant, otherwise: Variant) -> IfValue:
	var v := IfValue.new()
	v.when = when
	v.then = _v(then)
	v.otherwise = _v(otherwise)
	return v


func _stacks(status_id: String, on: ValueSource.On) -> StatusStacksValue:
	var v := StatusStacksValue.new()
	v.status = _statuses[status_id]
	v.on = on
	return v


func _hand_count(type_filter: int = 0, min_value: int = -999999) -> HandCountValue:
	var v := HandCountValue.new()
	v.type_filter = type_filter
	v.min_value = min_value
	return v


func _played(type_filter: int) -> PlayedThisTurnValue:
	var v := PlayedThisTurnValue.new()
	v.type_filter = type_filter
	return v


func _pile(pile: Pile.Id) -> PileSizeValue:
	var v := PileSizeValue.new()
	v.pile = pile
	return v


func _block_of(on: ValueSource.On) -> BlockValue:
	var v := BlockValue.new()
	v.on = on
	return v


func _missing_hp() -> MissingHpValue:
	return MissingHpValue.new()


func _stat(stat: ResolveStatValue.Stat) -> ResolveStatValue:
	var v := ResolveStatValue.new()
	v.stat = stat
	return v


func _hp_below(on: ValueSource.On, percent: int) -> HpBelowPercentCondition:
	var c := HpBelowPercentCondition.new()
	c.on = on
	c.percent = percent
	return c


func _last_type(type_filter: int) -> LastCardTypeCondition:
	var c := LastCardTypeCondition.new()
	c.type_filter = type_filter
	return c


func _hand_has(type_filter: int) -> HandHasTypeCondition:
	var c := HandHasTypeCondition.new()
	c.type_filter = type_filter
	return c


func _cmp(left: ValueSource, op: CompareCondition.Op, right: int) -> CompareCondition:
	var c := CompareCondition.new()
	c.left = left
	c.op = op
	c.right = _v(right)
	return c


func _block_at_least(on: ValueSource.On, value: int) -> BlockAtLeastCondition:
	var c := BlockAtLeastCondition.new()
	c.on = on
	c.value = value
	return c


func _dmg(amount: Variant, target: TargetRule, label: StringName = &"damage", hits: Variant = null,
		kind: DamageEffect.Kind = DamageEffect.Kind.ATTACK) -> DamageEffect:
	var e := DamageEffect.new()
	e.amount = _v(amount)
	e.target = target
	e.label = label
	e.hits = _v(hits) if hits != null else null
	e.kind = kind
	return e


func _block(amount: Variant, label: StringName = &"block") -> BlockEffect:
	var e := BlockEffect.new()
	e.amount = _v(amount)
	e.label = label
	return e


func _apply(status_id: String, stacks: Variant, target: TargetRule, label: StringName = &"") -> ApplyStatusEffect:
	var e := ApplyStatusEffect.new()
	e.status = _statuses[status_id]
	e.stacks = _v(stacks)
	e.target = target
	e.label = label
	return e


func _lose(amount: int) -> LoseHpEffect:
	var e := LoseHpEffect.new()
	e.amount = _v(amount)
	return e


func _energy(amount: int) -> GainEnergyEffect:
	var e := GainEnergyEffect.new()
	e.amount = _v(amount)
	return e


func _draw(count: Variant, label: StringName = &"") -> DrawEffect:
	var e := DrawEffect.new()
	e.count = _v(count)
	e.label = label
	return e


func _create(card_id: String, place: Pile.Place, count: int) -> CreateCardEffect:
	var e := CreateCardEffect.new()
	e.card = _cards[card_id]
	e.place = place
	e.count = _v(count)
	e.temporary = true
	return e


func _choose(source: Pile.Id, action: ChooseCardsEffect.Action, count: int, allow_fewer: bool = false,
		type_filter: int = 0) -> ChooseCardsEffect:
	var e := ChooseCardsEffect.new()
	e.source = source
	e.action = action
	e.count = count
	e.allow_fewer = allow_fewer
	e.type_filter = type_filter
	return e


func _discard_all(type_filter: int = 0) -> DiscardEffect:
	var e := DiscardEffect.new()
	e.mode = DiscardEffect.Mode.ALL
	e.type_filter = type_filter
	return e


func _exhaust_all(type_filter: int = 0) -> ExhaustEffect:
	var e := ExhaustEffect.new()
	e.mode = ExhaustEffect.Mode.ALL
	e.type_filter = type_filter
	return e


func _cost(scope: ModifyCostEffect.Scope, delta: int, this_turn_only: bool) -> ModifyCostEffect:
	var e := ModifyCostEffect.new()
	e.scope = scope
	e.delta = delta
	e.this_turn_only = this_turn_only
	return e


func _grow(amount: int) -> GrowCardEffect:
	var e := GrowCardEffect.new()
	e.amount = amount
	return e


func _consume(status_id: String, consume_all: bool, max_amount: int) -> ConsumeStatusEffect:
	var e := ConsumeStatusEffect.new()
	e.status = _statuses[status_id]
	e.target = _t_chosen
	e.consume_all = consume_all
	e.max_amount = max_amount
	return e


func _repeat(times: Variant, effects: Array) -> RepeatEffect:
	var e := RepeatEffect.new()
	e.times = _v(times)
	e.effects.assign(effects)
	return e


func _branch(when: Condition, then: Array, otherwise: Array = []) -> BranchEffect:
	var e := BranchEffect.new()
	e.when = when
	e.then.assign(then)
	e.otherwise.assign(otherwise)
	return e


## options: [[重み, [効果...]], ...]
func _random(options: Array) -> RandomChoiceEffect:
	var e := RandomChoiceEffect.new()
	for o: Array in options:
		var w := WeightedEffects.new()
		w.weight = o[0]
		w.effects.assign(o[1])
		e.options.append(w)
	return e


func _defer(timing: DeferEffect.Timing, effects: Array) -> DeferEffect:
	var e := DeferEffect.new()
	e.timing = timing
	e.effects.assign(effects)
	return e

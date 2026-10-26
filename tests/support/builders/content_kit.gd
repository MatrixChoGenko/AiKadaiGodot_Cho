class_name ContentKit extends RefCounted
## テスト支援：ルールのテスト用の小さなコンテンツをコードで組み立てる（正式コンテンツとは切り離す。Architecture §18.2）。
## ステータスは正式コンテンツと同じ Behavior の組み合わせで作るので、ルールの検証になる。

static var _statuses: Dictionary = {}


# —— ステータス ——

static func status(id: StringName) -> StatusData:
	if _statuses.has(id):
		return _statuses[id]
	var s := StatusData.new()
	s.id = id
	s.name = String(id)
	match id:
		&"strength":
			s.behaviors.append(FlatDamageBonus.new())
		&"vulnerable":
			s.polarity = StatusData.Polarity.DEBUFF
			s.decay = StatusData.Decay.LOSE_ONE_AT_ROUND_END
			var b := DamagePercent.new()
			b.direction = DamagePercent.Direction.INCOMING
			b.percent = 50
			s.behaviors.append(b)
		&"weak":
			s.polarity = StatusData.Polarity.DEBUFF
			s.decay = StatusData.Decay.LOSE_ONE_AT_ROUND_END
			var b := DamagePercent.new()
			b.percent = -25
			s.behaviors.append(b)
		&"poison":
			s.polarity = StatusData.Polarity.DEBUFF
			s.behaviors.append(DamageOverTime.new())
		&"regenerate":
			s.behaviors.append(HealOverTime.new())
		&"barricade":
			s.max_stacks = 1
			s.behaviors.append(KeepBlock.new())
		&"thorns":
			s.behaviors.append(Retaliate.new())
		&"artifact":
			s.behaviors.append(NegateDebuff.new())
		&"revive":
			s.behaviors.append(CheatDeath.new())
		&"demon_form":
			var b := GrantStatusOnTurnStart.new()
			b.status = status(&"strength")
			b.per_stack = 2
			s.behaviors.append(b)
		_:
			push_error("ContentKit: unknown status %s" % id)
	_statuses[id] = s
	return s


# —— 対象・値・条件 ——

static func chosen() -> ChosenTarget:
	return ChosenTarget.new()


static func me() -> SelfTarget:
	return SelfTarget.new()


static func all_enemies() -> AllEnemiesTarget:
	return AllEnemiesTarget.new()


static func random_enemy() -> RandomEnemiesTarget:
	return RandomEnemiesTarget.new()


static func v(x: Variant) -> ValueSource:
	if x is ValueSource:
		return x
	var f := FixedValue.new()
	f.value = x
	return f


static func scaled(base: int, per: int, unit: ValueSource) -> ScaledValue:
	var s := ScaledValue.new()
	s.base = base
	s.per = per
	s.unit = unit
	return s


static func stat(which: ResolveStatValue.Stat) -> ResolveStatValue:
	var s := ResolveStatValue.new()
	s.stat = which
	return s


# —— 効果 ——

static func dmg(amount: Variant, target: TargetRule = null, hits: Variant = null, label: StringName = &"damage") -> DamageEffect:
	var e := DamageEffect.new()
	e.amount = v(amount)
	e.target = target if target != null else chosen()
	e.hits = v(hits) if hits != null else null
	e.label = label
	return e


static func block(amount: Variant) -> BlockEffect:
	var e := BlockEffect.new()
	e.amount = v(amount)
	e.label = &"block"
	return e


static func apply(status_id: StringName, stacks: Variant, target: TargetRule = null) -> ApplyStatusEffect:
	var e := ApplyStatusEffect.new()
	e.status = status(status_id)
	e.stacks = v(stacks)
	e.target = target if target != null else chosen()
	return e


static func draw(n: Variant) -> DrawEffect:
	var e := DrawEffect.new()
	e.count = v(n)
	return e


static func energy(n: int) -> GainEnergyEffect:
	var e := GainEnergyEffect.new()
	e.amount = v(n)
	return e


static func lose_hp(n: int) -> LoseHpEffect:
	var e := LoseHpEffect.new()
	e.amount = v(n)
	return e


static func choose(source: Pile.Id, action: ChooseCardsEffect.Action, count: int, allow_fewer: bool = false) -> ChooseCardsEffect:
	var e := ChooseCardsEffect.new()
	e.source = source
	e.action = action
	e.count = count
	e.allow_fewer = allow_fewer
	return e


static func create(data: CardData, place: Pile.Place, count: int) -> CreateCardEffect:
	var e := CreateCardEffect.new()
	e.card = data
	e.place = place
	e.count = v(count)
	e.temporary = true
	return e


static func defer(timing: DeferEffect.Timing, effects: Array) -> DeferEffect:
	var e := DeferEffect.new()
	e.timing = timing
	e.effects.assign(effects)
	return e


static func repeat(times: Variant, effects: Array) -> RepeatEffect:
	var e := RepeatEffect.new()
	e.times = v(times)
	e.effects.assign(effects)
	return e


# —— カード ——

## opt: kw, aim（省略時は効果から自動）、type、on_discard / on_exhaust / on_draw / end_of_turn、cost_mode。
static func card(id: StringName, cost: int, on_play: Array, opt: Dictionary = {}) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = String(id)
	c.cost = cost
	c.type = opt.get("type", CardData.Type.SKILL)
	c.keywords = opt.get("kw", 0)
	c.cost_mode = opt.get("cost_mode", CardData.CostMode.FIXED)
	c.on_play.assign(on_play)
	c.on_draw.assign(opt.get("on_draw", []))
	c.on_discard.assign(opt.get("on_discard", []))
	c.on_exhaust.assign(opt.get("on_exhaust", []))
	c.end_of_turn_in_hand.assign(opt.get("end_of_turn", []))
	var uses_chosen := false
	for e in c.on_play:
		if e.target is ChosenTarget:
			uses_chosen = true
	c.aim = opt.get("aim", CardData.Aim.ENEMY if uses_chosen else CardData.Aim.NONE)
	return c


static func strike(amount: int = 6) -> CardData:
	return card(&"strike", 1, [dmg(amount)], {type = CardData.Type.ATTACK})


static func defend(amount: int = 5) -> CardData:
	return card(&"defend", 1, [block(amount)])


## 何もしない 0 コストのスキル（手札の枚数合わせ用）。
static func filler(id: StringName = &"filler") -> CardData:
	return card(id, 0, [])


# —— 敵 ——

## opt: weight, max_in_a_row, max_uses, phases, priority, forced_when, bonus_weight, bonus_when。
static func move(id: StringName, effects: Array, opt: Dictionary = {}) -> EnemyMove:
	var m := EnemyMove.new()
	m.id = id
	m.name = String(id)
	m.weight = opt.get("weight", 1)
	m.effects.assign(effects)
	for key: String in opt:
		if key != "weight":
			m.set(key, opt[key])
	return m


static func enemy(id: StringName, hp: int, moves: Array, opening: Array = [], loop: bool = false) -> EnemyData:
	var e := EnemyData.new()
	e.id = id
	e.name = String(id)
	e.hp_min = hp
	e.hp_max = hp
	e.moves.assign(moves)
	var ai := ScriptedAI.new()
	ai.opening.assign(opening)
	ai.loop_opening = loop
	e.ai = ai
	return e


## 毎ターン何もしない（ブロック 0）敵。
static func dummy(hp: int = 100) -> EnemyData:
	return enemy(&"dummy", hp, [move(&"wait", [block(0)])])


## 毎ターン amount の攻撃をする敵。
static func attacker(amount: int, hp: int = 100) -> EnemyData:
	return enemy(&"attacker", hp, [move(&"hit", [dmg(amount)])])


static func relic(id: StringName, behavior: CombatBehavior) -> RelicData:
	var r := RelicData.new()
	r.id = id
	r.name = String(id)
	r.behaviors.append(behavior)
	return r

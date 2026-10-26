class_name ContentFixture extends RefCounted
## テスト支援：バリデータのテスト用に、メモリ上だけで最小限の正しい ContentLibrary を組み立てる。
## 正式コンテンツとは切り離してあるので、バランス調整でテストが壊れない（Architecture §18.2）。


static func valid_library() -> ContentLibrary:
	var lib := ContentLibrary.new()
	for kind: KeywordData.Kind in KeywordData.Kind.values():
		var k := KeywordData.new()
		k.id = StringName(KeywordData.Kind.find_key(kind).to_lower())
		k.kind = kind
		k.name = k.id
		lib.keywords.append(k)

	var weak := StatusData.new()
	weak.id = &"weak"
	weak.name = "弱体"
	weak.text = "残り {stacks}"
	lib.statuses.append(weak)

	lib.cards.append(attack_card(&"strike", 6))

	var move := EnemyMove.new()
	move.id = &"bite"
	move.name = "噛みつき"
	move.weight = 1
	move.effects.append(damage(5, ChosenTarget.new()))
	var enemy := EnemyData.new()
	enemy.id = &"slime"
	enemy.name = "スライム"
	enemy.moves.append(move)
	enemy.ai = ScriptedAI.new()
	lib.enemies.append(enemy)

	var enc := EncounterData.new()
	enc.id = &"slime"
	enc.name = "スライム"
	enc.enemies.append(enemy)
	lib.encounters.append(enc)
	var boss := EncounterData.new()
	boss.id = &"boss"
	boss.name = "ボス"
	boss.rank = EnemyData.Rank.BOSS
	var boss_enemy := enemy.duplicate() as EnemyData
	boss_enemy.id = &"boss"
	boss_enemy.rank = EnemyData.Rank.BOSS
	lib.enemies.append(boss_enemy)
	boss.enemies.append(boss_enemy)
	lib.encounters.append(boss)

	var act := ActData.new()
	act.id = &"act_1"
	act.name = "第一幕"
	act.bosses.append(boss)
	lib.acts.append(act)

	var option := EventOption.new()
	option.text = "立ち去る"
	var ev := EventData.new()
	ev.id = &"camp"
	ev.title = "野営地"
	ev.options.append(option)
	lib.events.append(ev)

	var cfg := RunConfig.new()
	cfg.reward_card_count = 0
	cfg.starting_deck.append(lib.cards[0])
	lib.config = cfg
	return lib


static func attack_card(id: StringName, amount: int) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = String(id)
	c.aim = CardData.Aim.ENEMY
	c.text = "{damage} ダメージを与える。"
	c.on_play.append(damage(amount, ChosenTarget.new()))
	return c


static func damage(amount: int, target: TargetRule, label: StringName = &"damage") -> DamageEffect:
	var fixed := FixedValue.new()
	fixed.value = amount
	var e := DamageEffect.new()
	e.amount = fixed
	e.target = target
	e.label = label
	return e

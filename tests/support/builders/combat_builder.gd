class_name CombatBuilder extends RefCounted
## テスト支援：戦闘を組み立てる（Architecture §18.2）。各テストは自分に関係する部分だけを書けばよい。
## 既定：シャッフルしない、第 1 ターンの手札 = with_hand の順、第 2 ターン以降のドロー = 手札の枚数
## （with_draw_per_turn で変更）、エネルギー 3、敵の HP 固定。
##   CombatBuilder.new().with_hand([ContentKit.strike()]).with_enemy(ContentKit.dummy(50)).build()

var _setup: CombatSetup = CombatSetup.new()
var _hand: Array[CardData] = []
var _draw: Array[CardData] = []
var _enemies: Array[EnemyData] = []
var _enemy_hp: Array[int] = []
var _draw_per_turn: int = -1


func _init() -> void:
	_setup.config = RunConfig.new()
	_setup.rng = RngStreams.new(12345)
	_setup.keep_deck_order = true
	_setup.interactive = true


## 第 1 ターンの手札（この順に引く）。
func with_hand(cards: Array) -> CombatBuilder:
	_hand.assign(cards)
	return self


## 手札の下に積む山札（配列の先頭が先に引かれる）。
func with_draw_pile(cards: Array) -> CombatBuilder:
	_draw.assign(cards)
	return self


func with_enemy(data: EnemyData, hp: int = -1) -> CombatBuilder:
	_enemies.append(data)
	_enemy_hp.append(hp)
	return self


func with_player(hp: int, max_hp: int = -1) -> CombatBuilder:
	_setup.player_hp = hp
	_setup.player_max_hp = max_hp if max_hp > 0 else hp
	return self


func with_energy(n: int) -> CombatBuilder:
	_setup.energy_per_turn = n
	return self


func with_draw_per_turn(n: int) -> CombatBuilder:
	_draw_per_turn = n
	return self


func with_relic(data: RelicData) -> CombatBuilder:
	_setup.relics.append(RelicSlot.new(data))
	return self


func with_potions(list: Array) -> CombatBuilder:
	_setup.potions.assign(list)
	return self


func with_seed(seed_value: int) -> CombatBuilder:
	_setup.rng = RngStreams.new(seed_value)
	return self


func with_config(config: RunConfig) -> CombatBuilder:
	_setup.config = config
	return self


## false にすると人間の操作待ちをせず、カード選択を AutoChooser が即答する。
func interactive(on: bool) -> CombatBuilder:
	_setup.interactive = on
	return self


func shuffled() -> CombatBuilder:
	_setup.keep_deck_order = false
	return self


func build() -> CombatHarness:
	if _enemies.is_empty():
		with_enemy(ContentKit.dummy())
	var encounter := EncounterData.new()
	encounter.id = &"test"
	encounter.enemies.assign(_enemies)
	_setup.encounter = encounter
	var uid := 1
	# 山札の末尾が一番上。手札の 1 枚目を最初に引くように並べる。
	var order: Array[CardData] = []
	for i in range(_draw.size() - 1, -1, -1):
		order.append(_draw[i])
	for i in range(_hand.size() - 1, -1, -1):
		order.append(_hand[i])
	for data in order:
		_setup.deck.append(Card.new(uid, data))
		uid += 1
	_setup.draw_per_turn = _hand.size()   # 第 1 ターンは必ず with_hand の全部を引く
	var combat := Combat.create(_setup)
	for i in combat.enemies.size():
		if _enemy_hp[i] > 0:
			combat.enemies[i].hp = _enemy_hp[i]
			combat.enemies[i].max_hp = _enemy_hp[i]
	var ctl := CombatController.from_combat(combat)
	var harness := CombatHarness.new(ctl, _setup.deck.size())
	ctl.start()
	if _draw_per_turn >= 0:
		combat.draw_per_turn = _draw_per_turn   # 第 2 ターン以降のドロー枚数
	return harness

extends Node
## ⑤ Presentation（デバッグ）：単独戦闘のデバッグシーン（Architecture §19、T03）。
## Inspector でエンカウント・デッキ・レリック・ポーション・シードを指定し、F6 でこのシーンを実行するとすぐ戦える。
## 空の項目は RunConfig の初期値を使う。戦闘が終わって「続ける」を押すと、シードを 1 つ進めてやり直す。

const COMBAT_SCENE: PackedScene = preload("res://scenes/screens/combat.tscn")

@export var encounter: EncounterData
## 空 = 初期デッキ。
@export var deck: Array[CardData] = []
## 空 = 初期レリック。
@export var relics: Array[RelicData] = []
@export var potions: Array[PotionData] = []
@export var seed_value: int = 1
@export_range(1, 999) var player_hp: int = 80
## 山札をシャッフルしない（deck の末尾から引く）。
@export var keep_deck_order: bool = false

var combat: CombatController

@onready var _screen_host: ScreenHost = %ScreenHost
@onready var _modals: ModalHost = %ModalHost


func _ready() -> void:
	start()


func start() -> void:
	var lib := Content.library
	var cfg := lib.config
	var setup := CombatSetup.new()
	setup.encounter = encounter if encounter != null else lib.encounter(&"jawworm")
	setup.config = cfg
	setup.rng = RngStreams.new(seed_value)
	setup.player_hp = player_hp
	setup.player_max_hp = player_hp
	setup.energy_per_turn = cfg.energy_per_turn
	setup.draw_per_turn = cfg.draw_per_turn
	setup.keep_deck_order = keep_deck_order
	var cards := deck if not deck.is_empty() else cfg.starting_deck
	for i in cards.size():
		setup.deck.append(Card.new(i + 1, cards[i]))
	for r in (relics if not relics.is_empty() else cfg.starting_relics):
		setup.relics.append(RelicSlot.new(r))
	for i in maxi(cfg.potion_slots, potions.size()):
		setup.potions.append(potions[i] if i < potions.size() else null)
	_modals.clear()
	Fx.clear()
	combat = CombatController.from_combat(Combat.create(setup))
	combat.start()
	var screen := _screen_host.show_screen(COMBAT_SCENE, {combat = combat, modals = _modals}) as CombatScreen
	screen.sandbox_continue.connect(_on_sandbox_continue)
	Log.info(&"combat", "sandbox: %s (seed %d)" % [setup.encounter.id, seed_value])


func _on_sandbox_continue() -> void:
	seed_value += 1
	start()

class_name CombatSetup extends RefCounted
## ③ Domain：戦闘を始めるための入力（RunState から作る。テストでは CombatBuilder が作る）。

var encounter: EncounterData
var config: RunConfig
var rng: RngStreams
var player_name: String = "プレイヤー"
var player_hp: int = 80
var player_max_hp: int = 80
var energy_per_turn: int = 3
var draw_per_turn: int = 5
## ラン中のデッキ。戦闘ではこの Card オブジェクトがそのまま山を移動し、終了時に戦闘中の値が戻される。
var deck: Array[Card] = []
var relics: Array[RelicSlot] = []
## ポーション枠。空きは null。
var potions: Array[PotionData] = []
## 人間が操作するか。true ならカード選択で一時停止する。false なら AutoChooser が即答する。
var interactive: bool = true
## テスト用：シャッフルせず、deck の順番のまま山札にする（配列の末尾が一番上）。
var keep_deck_order: bool = false
## テスト用：敵の HP を固定する（-1 = 範囲から抽選）。
var fixed_enemy_hp: int = -1
## 協力プレイ：プレイヤーごとの入力。空なら上の player_* / deck / relics / potions で席 1 つ（1 人プレイ）。
var seats: Array[CombatSeatSetup] = []

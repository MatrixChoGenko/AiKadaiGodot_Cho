class_name EnemyMove extends Resource
## ② Content：敵の行動 1 つ（GameDesign §11.1 / Architecture §5.2）。行動の不変の識別子は id（リストの添字ではない）。

## インテントのアイコン。AUTO = 効果の preview() から自動で決める（Architecture §9.4）。
enum IntentHint { AUTO, ATTACK, ATTACK_DEFEND, ATTACK_DEBUFF, DEFEND, BUFF, DEBUFF, SPECIAL, SLEEP, UNKNOWN }

@export var id: StringName
@export var name: String
@export var intent: IntentHint = IntentHint.AUTO
@export var effects: Array[CardEffect] = []
@export_group("Weighted")
@export_range(0, 1000) var weight: int = 0
@export_range(0, 1000) var bonus_weight: int = 0
## 成立すると bonus_weight を足す。
@export var bonus_when: Condition
@export_group("Limits")
## 使用できる条件。null = 常に使える。
@export var usable_when: Condition
## 連続使用の上限。0 = 無制限。
@export_range(0, 10) var max_in_a_row: int = 0
## 使用後に使えないターン数。
@export_range(0, 10) var cooldown: int = 0
## 1 戦闘あたりの使用回数の上限。0 = 無制限。
@export_range(0, 10) var max_uses: int = 0
## 使えるフェーズ（ビット）。0 = すべてのフェーズ。
@export_flags("Phase1", "Phase2", "Phase3", "Phase4") var phases: int = 0
@export_group("Forced")
## 0 より大きく、forced_when が成立し、使用可能なら強制的に選ばれる。値が大きいほど優先。
@export_range(0, 100) var priority: int = 0
@export var forced_when: Condition

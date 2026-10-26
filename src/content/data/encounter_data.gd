class_name EncounterData extends Resource
## ② Content：エンカウント（1 戦闘に出る敵の組み合わせ。GameDesign §11.3）。

@export var id: StringName
@export var name: String
@export var rank: EnemyData.Rank = EnemyData.Rank.NORMAL
@export var enemies: Array[EnemyData] = []
## 序盤（RunConfig.early_battle_rows より前の行）の通常戦闘にも出る。序盤の行はこれだけから選ぶ。
@export var early: bool = false
## 出現可能なアクト（ビット）。
@export_flags("Act1", "Act2", "Act3", "Act4", "Act5", "Act6") var acts: int = 1
## 戦闘背景。null = アクトの背景を使う。
@export var backdrop: BackdropData

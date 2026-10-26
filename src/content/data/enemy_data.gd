class_name EnemyData extends Resource
## ② Content：敵の定義（GameDesign §11.2）。行動の選び方は ai（ステートレスな Strategy）に任せる。

enum Rank { NORMAL, ELITE, BOSS }

@export var id: StringName
@export var name: String
@export var art: Texture2D
@export var rank: Rank = Rank.NORMAL
@export_range(1, 9999) var hp_min: int = 10
@export_range(1, 9999) var hp_max: int = 10
@export var starting_statuses: Dictionary[StatusData, int] = {}
@export var moves: Array[EnemyMove] = []
@export var ai: EnemyAI

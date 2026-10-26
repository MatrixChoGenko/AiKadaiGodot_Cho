class_name StatusData extends Resource
## ② Content：ステータス（バフ / デバフ）定義（GameDesign §8）。持続ルールは behaviors に持つ。

enum Polarity { BUFF, DEBUFF, NEUTRAL }
## 減衰ルール。ROUND_END = 全ユニットの行動が終わった時点（敵のターンの後）に -1。
## 敵のターン中に付与されたスタックは、そのラウンドの減衰を受けない（GameDesign §8 の M1 決定事項）。
enum Decay { NONE, LOSE_ONE_AT_ROUND_END, CLEAR_AT_TURN_END, CLEAR_AT_TURN_START }

@export var id: StringName
@export var name: String
@export var icon: Texture2D
@export var polarity: Polarity = Polarity.BUFF
@export var decay: Decay = Decay.NONE
@export_range(1, 999) var max_stacks: int = 999
@export var behaviors: Array[CombatBehavior] = []
## 説明文。`{stacks}` が現在のスタック数に置き換わる。
@export_multiline var text: String

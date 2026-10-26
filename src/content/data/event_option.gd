class_name EventOption extends Resource
## ② Content：イベントの選択肢 1 つ（GameDesign §12.4）。

## 選択肢の名前（1 行目、金色）。
@export var text: String
## 効果の説明（2 行目。空なら名前だけ）。ゴールド・HP・呪いの部分は画面が色を付ける（UiText.event_detail_markup）。
@export var detail: String
## 選べる条件。null = 常に選べる。満たさないとグレーアウトし disabled_hint を表示する。
@export var requires: RunCondition
@export var disabled_hint: String
@export var effects: Array[RunEffect] = []
@export_multiline var result_text: String

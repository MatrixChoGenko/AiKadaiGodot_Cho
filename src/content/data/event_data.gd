class_name EventData extends Resource
## ② Content：ランダムイベント（GameDesign §12.4）。

@export var id: StringName
@export var title: String
@export var art: Texture2D
@export_multiline var body: String
## この行以降のマップノードにだけ出る。
@export_range(0, 50) var min_row: int = 0
@export_flags("Act1", "Act2", "Act3", "Act4", "Act5", "Act6") var acts: int = 1
@export var options: Array[EventOption] = []

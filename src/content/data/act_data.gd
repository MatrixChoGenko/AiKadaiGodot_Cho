class_name ActData extends Resource
## ② Content：アクト（GameDesign §3.3 / §4.1）。マップの形とボスのプールを持つ。

@export var id: StringName
@export var name: String
## アクトの順番（1 始まり）。EncounterData.acts / EventData.acts のビットと対応する。
@export_range(1, 6) var number: int = 1
@export_range(3, 50) var rows: int = 15
@export_range(3, 15) var columns: int = 7
@export_range(1, 15) var paths: int = 6
@export var bosses: Array[EncounterData] = []
@export var backdrop: BackdropData

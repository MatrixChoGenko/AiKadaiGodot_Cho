class_name KeywordData extends Resource
## ② Content：カードのキーワードの説明（ホバー時のツールチップ。GameDesign §6.2）。

## CardData.Keyword のビット値。UNPLAYABLE は CardData.CostMode.UNPLAYABLE に対応する。
enum Kind { EXHAUST = 1, RETAIN = 2, INNATE = 4, ETHEREAL = 8, UNPLAYABLE = 16 }

@export var id: StringName
@export var kind: Kind = Kind.EXHAUST
@export var name: String
@export_multiline var text: String

class_name WeightedEffects extends Resource
## ② Content：RandomChoiceEffect の選択肢 1 つ（重み + 子効果）。ステートレス。

@export_range(0, 1000) var weight: int = 1
@export var effects: Array[CardEffect] = []

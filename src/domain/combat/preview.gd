class_name Preview extends RefCounted
## ③ Domain：プレビューの集計先。効果の preview() が書き込む。
## カード面の数値（label → 値）と、敵のインテントの材料（攻撃・防御・バフ…）の両方に使う。

## label → 現在の値（補正後）。
var values: Dictionary[StringName, int] = {}
## label → 基本値（補正前）。カードテキストの色分け（高い = 緑 / 低い = 赤）に使う。
var base_values: Dictionary[StringName, int] = {}

# —— インテントの材料 ——
## 1 ヒットあたりの攻撃ダメージ（最初の攻撃の値）。
var attack_damage: int = 0
var attack_hits: int = 0
var block: int = 0
var buffs: bool = false
var debuffs: bool = false
var special: bool = false
## ランダムな選択があり、行動の内容が確定しない。
var uncertain: bool = false
## 遅延効果の中など、インテントの集計に数えない部分を辿っている。
var muted: int = 0


func set_label(label: StringName, value: int, base: int) -> void:
	if label.is_empty():
		return
	values[label] = value
	base_values[label] = base


func add_attack(per_hit: int, hits: int) -> void:
	if muted > 0:
		return
	if attack_hits == 0:
		attack_damage = per_hit
	attack_hits += hits

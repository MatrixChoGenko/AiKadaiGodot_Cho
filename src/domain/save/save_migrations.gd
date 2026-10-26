class_name SaveMigrations extends RefCounted
## ③ Domain：セーブのバージョン移行（Architecture §12.2）。移行は func(d: Dictionary) -> Dictionary の列で、
## STEPS の i 番目がバージョン i + 1 → i + 2 を担当する。形式の意味を変えたら CURRENT_VERSION を上げて 1 つ追加する。

const CURRENT_VERSION: int = 1


## 既定の移行の列。今はバージョン 1 だけなので空。
static func default_steps() -> Array[Callable]:
	return []


## d を target の版まで順に移行する。版が無い / 新しすぎる / 移行が足りないときは空の Dictionary を返す。
static func migrate(d: Dictionary, steps: Array[Callable] = default_steps(), target: int = CURRENT_VERSION) -> Dictionary:
	if not d.has("version"):
		return {}
	var version := int(d["version"])
	if version < 1 or version > target:
		return {}
	var out := d
	while version < target:
		var i := version - 1
		if i >= steps.size():
			return {}
		out = steps[i].call(out.duplicate(true))
		version += 1
		out["version"] = version
	return out

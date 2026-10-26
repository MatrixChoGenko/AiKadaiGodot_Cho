class_name RngStreams extends RefCounted
## ③ Domain：名前付きの独立した乱数ストリーム（Architecture §11）。
## ストリームごとの起点は FNV-1a（自前の決定的ハッシュ）で作る。Godot の hash() はバージョン間で同じ値の保証がないため。
## セーブには各ストリームの state を**文字列**で保存する（JSON は数値を double で読むので 64bit 整数が壊れる）。

const STREAMS: Array[StringName] = [&"map", &"encounter", &"draw", &"combat", &"enemy_ai",
		&"reward", &"shop", &"event", &"card_effect", &"potion", &"coop"]

const _FNV_OFFSET: int = -3750763034362895579   # 14695981039346656037 を符号付き 64bit で表したもの
const _FNV_PRIME: int = 1099511628211

var _gens: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(seed_value: int = 0) -> void:
	for s in STREAMS:
		var g := RandomNumberGenerator.new()
		g.seed = derive_seed(seed_value, s)
		_gens[s] = g


## マスターシードとストリーム名から、そのストリームの起点を作る（FNV-1a 64bit）。
static func derive_seed(seed_value: int, stream: StringName) -> int:
	var h := _FNV_OFFSET
	for b in ("%d:%s" % [seed_value, stream]).to_utf8_buffer():
		h = (h ^ b) * _FNV_PRIME
	return h


## lo 以上 hi_inclusive 以下の整数。
func range_int(stream: StringName, lo: int, hi_inclusive: int) -> int:
	if hi_inclusive <= lo:
		return lo
	return _gen(stream).randi_range(lo, hi_inclusive)


## percent% の確率で true。
func chance(stream: StringName, percent: int) -> bool:
	if percent <= 0:
		return false
	if percent >= 100:
		return true
	return _gen(stream).randi_range(0, 99) < percent


## 配列から 1 つ選ぶ。空なら null。
func pick(stream: StringName, items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[range_int(stream, 0, items.size() - 1)]


## Fisher–Yates でその場でシャッフルする。
func shuffle(stream: StringName, items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := range_int(stream, 0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


## 重みの添字を 1 つ選ぶ。重みの合計が 0 以下なら -1。
func weighted(stream: StringName, weights: PackedInt32Array) -> int:
	var total := 0
	for w in weights:
		total += maxi(w, 0)
	if total <= 0:
		return -1
	var roll := range_int(stream, 0, total - 1)
	for i in weights.size():
		roll -= maxi(weights[i], 0)
		if roll < 0:
			return i
	return weights.size() - 1


## { ストリーム名: state の文字列 }
func save() -> Dictionary:
	var d: Dictionary = {}
	for s in STREAMS:
		d[String(s)] = str(_gens[s].state)
	return d


func restore(d: Dictionary) -> void:
	for s in STREAMS:
		var key := String(s)
		if d.has(key):
			_gens[s].state = String(d[key]).to_int()


func _gen(stream: StringName) -> RandomNumberGenerator:
	var g: RandomNumberGenerator = _gens.get(stream)
	assert(g != null, "RngStreams: unknown stream %s" % stream)
	return g

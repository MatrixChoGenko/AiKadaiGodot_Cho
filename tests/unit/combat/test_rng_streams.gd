extends GutTest
## RngStreams：決定性・ストリームの独立・セーブ / ロード（Architecture §11）。


func test_same_seed_same_sequence() -> void:
	var a := RngStreams.new(42)
	var b := RngStreams.new(42)
	for i in 50:
		assert_eq(a.range_int(&"draw", 0, 1000), b.range_int(&"draw", 0, 1000))


func test_streams_are_independent() -> void:
	var a := RngStreams.new(7)
	var b := RngStreams.new(7)
	for i in 30:
		a.range_int(&"combat", 0, 100)   # a だけ combat を消費する
	for i in 20:
		assert_eq(a.range_int(&"reward", 0, 1000), b.range_int(&"reward", 0, 1000))


func test_derive_seed_is_stable() -> void:
	# 自前の FNV-1a なので Godot のバージョンが変わっても同じ値になる。値が変わったらセーブ互換が壊れる。
	assert_eq(RngStreams.derive_seed(1, &"map"), RngStreams.derive_seed(1, &"map"))
	assert_ne(RngStreams.derive_seed(1, &"map"), RngStreams.derive_seed(2, &"map"))
	assert_ne(RngStreams.derive_seed(1, &"map"), RngStreams.derive_seed(1, &"draw"))


func test_save_restore_resumes_exactly_through_json() -> void:
	var a := RngStreams.new(99)
	for i in 17:
		a.range_int(&"shop", 0, 100)
	var saved := JSON.parse_string(JSON.stringify(a.save())) as Dictionary   # JSON を通しても壊れない（state は文字列）
	var b := RngStreams.new(0)
	b.restore(saved)
	for i in 30:
		assert_eq(a.range_int(&"shop", 0, 1 << 30), b.range_int(&"shop", 0, 1 << 30))


func test_weighted_and_chance_bounds() -> void:
	var r := RngStreams.new(3)
	assert_eq(r.weighted(&"map", PackedInt32Array([0, 0])), -1)
	assert_eq(r.weighted(&"map", PackedInt32Array([0, 5, 0])), 1)
	assert_false(r.chance(&"map", 0))
	assert_true(r.chance(&"map", 100))


func test_shuffle_is_deterministic_permutation() -> void:
	var a := [1, 2, 3, 4, 5, 6, 7, 8]
	var b := a.duplicate()
	RngStreams.new(5).shuffle(&"draw", a)
	RngStreams.new(5).shuffle(&"draw", b)
	assert_eq(a, b)
	var sorted := a.duplicate()
	sorted.sort()
	assert_eq(sorted, [1, 2, 3, 4, 5, 6, 7, 8])

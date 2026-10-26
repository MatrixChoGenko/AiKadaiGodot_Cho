extends SceneTree
## Map node statistics: per map and per random path (uniform choice at each fork).

const N := 2000
const NAMES := ["BATTLE", "ELITE", "BOSS", "EVENT", "SHOP", "REST", "TREASURE"]


func _initialize() -> void:
	var lib = load("res://content/content_library.tres")
	var config = load("res://content/balance/run_config.tres")
	var gen = load("res://src/domain/map/map_generator.gd")
	var streams = load("res://src/domain/rng/rng_streams.gd")
	var act = lib.acts[0]
	var args := OS.get_cmdline_user_args()
	if args.size() >= 5:
		config = config.duplicate()
		var w := PackedInt32Array()
		for a in args:
			w.append(int(a))
		config.node_weights = w
		print("weights ", config.node_weights)
	var early_ids := {}
	var per_map := {}
	var per_path := {}
	var first_row := {}   # type -> sum of first row seen on path (only if seen)
	var seen := {}
	var early := {}       # type count on path rows 0..4
	var battles_before_rest := 0.0
	for t in NAMES.size():
		per_map[t] = 0.0; per_path[t] = 0.0; first_row[t] = 0.0; seen[t] = 0.0; early[t] = 0.0
	var pick := RandomNumberGenerator.new()
	pick.seed = 12345
	for i in N:
		var rng = streams.new(i + 1)
		var map = gen.generate(rng, act, lib, config)
		for n in map.nodes:
			per_map[n.type] += 1
			if n.type == 0 and n.row < config.early_battle_rows:
				early_ids[n.encounter] = early_ids.get(n.encounter, 0) + 1
		var starts = map.start_nodes()
		var cur = starts[pick.randi_range(0, starts.size() - 1)]
		var got := {}
		var fights := 0
		var rested := false
		while cur != null and cur.type != 2:
			per_path[cur.type] += 1
			if cur.row <= 4:
				early[cur.type] += 1
			if not got.has(cur.type):
				got[cur.type] = true
				first_row[cur.type] += cur.row
				seen[cur.type] += 1
			if not rested:
				if cur.type == 5:
					rested = true
				elif cur.type == 0 or cur.type == 1:
					fights += 1
			if cur.next.is_empty():
				break
			cur = map.node(cur.next[pick.randi_range(0, cur.next.size() - 1)])
		battles_before_rest += fights
	print("type      per_map  per_path  rows0-4  first_row(avg, if seen)  seen%")
	for t in NAMES.size():
		if t == 2:
			continue
		var fr: float = first_row[t] / seen[t] if seen[t] > 0 else -1.0
		print("%-9s %7.2f %9.2f %8.2f %12.2f %18.0f" % [NAMES[t], per_map[t] / N, per_path[t] / N,
				early[t] / N, fr, 100.0 * seen[t] / N])
	print("early-row encounters: ", early_ids)
	print("fights before first rest (avg): %.2f" % (battles_before_rest / N))
	quit()

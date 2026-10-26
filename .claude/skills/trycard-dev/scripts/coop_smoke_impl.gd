extends RefCounted
## coop_smoke.gd の本体。引数：role（host / client）、port、seed。
## ホストは参加者が来るまで待ってから開始し、両方とも UiBot でランを最後まで進める。
## 短くするため 1 アクト 7 行のライブラリと HP 600 の設定を使う（両方で同じ。版の検査は Content.library で行うので通る）。

const FRAME_LIMIT: int = 120000
const WAIT_SECONDS: float = 60.0

var tree: SceneTree
var role: String = "host"
var port: int = 24680
var seed_value: int = 1
var desyncs: int = 0


func start(p_tree: SceneTree) -> void:
	tree = p_tree
	var a := OS.get_cmdline_user_args()
	if a.size() >= 1:
		role = a[0]
	if a.size() >= 2:
		port = a[1].to_int()
	if a.size() >= 3:
		seed_value = a[2].to_int()
	await _run()


func _run() -> void:
	var root := tree.root
	var net := root.get_node("Net")
	net.set("port", port)
	net.set("discovery_port", port + 1)
	net.connect("desync_detected", func(_seq: int) -> void: desyncs += 1)
	var save := root.get_node("SaveManager")
	save.set("run_path", "user://test_saves/coop_smoke_%s.json" % role)
	save.set("coop_path", "user://test_saves/coop_smoke_coop_%s.json" % role)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var lib: ContentLibrary = RunFixtures.short_library(Content.library, 1, 7)
	main.set("content_override", lib)
	# HP を多めにして、マップの最後（ボス）まで進むようにする（ショップ・休憩・イベント・宝箱も通る）。
	main.set("config_override", RunFixtures.tough_config(Content.library.config, 600))
	root.add_child(main)
	await _frames(10)
	var ok := false
	if role == "host":
		ok = net.call("host", "ホスト")
		if ok:
			ok = await _until(func() -> bool: return (net.get("members") as Array).size() >= 2)
		if ok:
			net.call("start_run", seed_value)
	else:
		for attempt in 20:
			net.call("join", "127.0.0.1", "ゲスト")
			ok = await _until(func() -> bool: return (net.get("members") as Array).size() >= 2, 3.0)
			if ok:
				break
	if not ok:
		_finish({failure = "could not connect: %s" % net.get("last_error")})
		return
	ok = await _until(func() -> bool: return main.get("run") != null)
	if not ok:
		_finish({failure = "run did not start"})
		return
	var bot := UiBot.new(main, seed_value * 7 + (0 if role == "host" else 1))
	var frames := 0
	while frames < FRAME_LIMIT:
		var screen: Node = main.call(&"current_screen")
		if screen is CombatScreen:
			(screen as CombatScreen).presenter.instant = true
		if not bot.step():
			break
		await tree.process_frame
		frames += 1
	var run: RunController = main.get("run")
	_finish({
		failure = bot.failure if frames < FRAME_LIMIT else "frame limit on %s" % main.call(&"current_screen"),
		outcome = bot.stats.outcome, combats = bot.stats.combats, cards = bot.stats.cards_played,
		rewards = bot.stats.rewards, events = bot.stats.events, frames = frames,
		battles_won = run.state.battles_won if run != null and run.state != null else -1,
	})


func _finish(result: Dictionary) -> void:
	result.role = role
	result.desyncs = desyncs
	print("COOP_SMOKE ", JSON.stringify(result))
	await _frames(30)
	tree.quit(0 if String(result.get("failure", "")) == "" and desyncs == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _until(cond: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()

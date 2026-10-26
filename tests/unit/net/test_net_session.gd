extends GutTest
## 協力プレイの通信（Net。GameDesign §21 / Architecture §23）を、1 つのプロセスの中で 2 台分動かして確かめる。
## ホスト側 / 参加者側をそれぞれ別の SceneMultiplayer の枝に置き、本物の ENet で localhost につなぐ。
## 両方とも /<枝>/Net にあるので RPC のパスがそろう。

const NetScript = preload("res://src/platform/net_session.gd")
const TEST_PORT: int = 24690
const F = preload("res://tests/support/builders/run_fixtures.gd")

var _host_root: Node
var _client_root: Node
var _host: Node
var _client: Node
var _desyncs: int = 0


func before_each() -> void:
	_desyncs = 0
	_host_root = _branch("HostSide")
	_client_root = _branch("ClientSide")
	_host = _net(_host_root)
	_client = _net(_client_root)


func after_each() -> void:
	for net: Node in [_client, _host]:
		if is_instance_valid(net):
			net.leave()
	for root: Node in [_client_root, _host_root]:
		if is_instance_valid(root):
			get_tree().set_multiplayer(null, root.get_path())
			root.queue_free()
	await wait_process_frames(2)


func _branch(n: String) -> Node:
	var root := Node.new()
	root.name = n
	get_tree().root.add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	return root


func _net(root: Node) -> Node:
	var net: Node = NetScript.new()
	net.name = "Net"
	net.port = TEST_PORT
	net.discovery_port = TEST_PORT + 1
	root.add_child(net)
	net.run_starting.connect(_on_run_starting.bind(net))
	net.desync_detected.connect(func(_seq: int) -> void: _desyncs += 1)
	return net


## Main の代わり：ランを作って Net に渡す。
func _on_run_starting(info: Dictionary, net: Node) -> void:
	var run := RunController.new(OfficialSetup.library())
	net.run = run
	if String(info.mode) == "resume":
		run.resume(RunSerializer.new().from_dict(info.save, run.content))
	else:
		run.start_new(String(info.seed).to_int(), true, PackedStringArray(info.names))


func _wait_until(cond: Callable, seconds: float = 5.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
		if t == 0.0:
			t += 0.001
	return cond.call()


func _connect_both() -> void:
	assert_true(_host.host("ホスト"), _host.last_error)
	assert_true(_client.join("127.0.0.1", "ゲスト"))
	var ok: bool = await _wait_until(func() -> bool: return _host.members.size() == 2 and _client.members.size() == 2)
	assert_true(ok, "ロビーに 2 人そろう")


func test_lobby_assigns_seats_in_join_order() -> void:
	await _connect_both()
	assert_eq(_host.seat, 0)
	assert_eq(_client.seat, 1)
	assert_eq(_client.names(), PackedStringArray(["ホスト", "ゲスト"]))


func test_commands_keep_both_runs_identical() -> void:
	await _connect_both()
	_host.start_run(4242)
	var started: bool = await _wait_until(func() -> bool: return _client.run != null and _host.run != null)
	assert_true(started, "両方でランが始まる")
	var hr: RunController = _host.run
	var cr: RunController = _client.run
	assert_eq(hr.state.players.size(), 2)
	assert_eq(F.dump(hr.state), F.dump(cr.state), "開始時点で同じ")
	# 両方が同じノードに投票 → 戦闘へ（マップの書き換えは両方に同じことをする）
	var node := F.force_next(hr, MapNode.Type.BATTLE, &"jawworm")
	F.force_next(cr, MapNode.Type.BATTLE, &"jawworm")
	_client.submit(CoopCommands.VOTE, {node = node})
	_host.submit(CoopCommands.VOTE, {node = node})
	var in_combat: bool = await _wait_until(func() -> bool: return cr.combat != null and hr.combat != null)
	assert_true(in_combat, "全員が投票したら戦闘")
	# それぞれ自分の手札を出し、ターンを終える
	for net: Node in [_client, _host]:
		var run: RunController = net.run
		var seat_cards := run.combat.seat_at(net.seat).piles.hand.duplicate()
		for card: Card in seat_cards:
			var target: int = run.combat.combat.alive_enemies()[0].uid if card.data.aim == CardData.Aim.ENEMY else -1
			net.submit(CoopCommands.PLAY, {card = card.uid, target = target})
	_client.submit(CoopCommands.END_TURN)
	_host.submit(CoopCommands.END_TURN)
	var next_turn: bool = await _wait_until(func() -> bool:
		return cr.combat != null and cr.combat.combat.seats[0].turn.number >= 2 and hr.combat.combat.seats[0].turn.number >= 2)
	assert_true(next_turn, "2 人とも Ready → 敵のターン → 次のターン")
	await wait_process_frames(5)
	assert_eq(_desyncs, 0, "ずれは検出されない")
	assert_eq(CoopCommands.digest(hr), CoopCommands.digest(cr))
	assert_eq(hr.combat.combat.events.size(), cr.combat.combat.events.size())


func test_rejected_command_calls_back_false() -> void:
	await _connect_both()
	_host.start_run(7)
	await _wait_until(func() -> bool: return _client.run != null)
	var result := [null]
	_client.submit(CoopCommands.BUY, {item = 0}, func(ok: bool) -> void: result[0] = ok)
	var answered: bool = await _wait_until(func() -> bool: return result[0] != null)
	assert_true(answered)
	assert_eq(result[0], false, "マップでは買えない")


func test_client_leaving_mid_run_ends_the_session_for_host() -> void:
	await _connect_both()
	_host.start_run(9)
	await _wait_until(func() -> bool: return _client.run != null)
	var reasons: Array[String] = []
	_host.session_ended.connect(func(r: String) -> void: reasons.append(r))
	_client.leave()
	var ended: bool = await _wait_until(func() -> bool: return not reasons.is_empty())
	assert_true(ended, "ホストに切断が伝わる")
	assert_false(_host.is_active())


func test_refuses_different_version() -> void:
	assert_true(_host.host("ホスト"))
	var reasons: Array[String] = []
	_client.session_ended.connect(func(r: String) -> void: reasons.append(r))
	_client.version_override = "old|0|[]"
	_client.join("127.0.0.1", "古い版")
	var refused: bool = await _wait_until(func() -> bool: return not reasons.is_empty())
	assert_true(refused, "断られる")
	assert_string_contains(reasons[0], "版が違います")
	assert_eq(_host.members.size(), 1, "版が違う人は入れない")

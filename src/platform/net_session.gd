extends Node
## ① Platform（Autoload "Net"）：協力プレイの通信（GameDesign §21 / Architecture §23）。
## - 接続：ENet（UDP）。ホストが PORT で待ち受け、参加者は IP を指定して接続する。最大 MAX_PLAYERS 人。
## - LAN 内の自動検出：ホストが DISCOVERY_PORT へ 1 秒ごとにブロードキャストし、参加画面が受信して一覧にする。
## - ロビー：席の番号 = 接続の順（ホストが席 0）。版とコンテンツが違う PC は入れない。
## - ラン中の同期はロックステップ：各自の操作は submit() でホストへ送り、ホストが通し番号を付けて自分で実行し、
##   受け付けられたものだけを全員へ配る。全員が同じ順番で CoopCommands.apply() するので同じ状態になる。
##   ホストは実行後の要約（digest）を添え、参加者は自分の要約と比べてずれを検出する。
## - 切断：誰かが抜けたらセッションを終える（ホストのセーブから全員で再開する。途中参加・再接続はしない）。

signal lobby_changed
## 参加者：ホストへの接続に失敗した / 断られた / 切れた。ホスト：誰かが抜けた。
signal session_ended(reason: String)
## ランを始める（Main が受ける）。info = {mode: "new" | "resume", seed, names, save}。
signal run_starting(info: Dictionary)
## コマンドが全員の状態に適用された（自分のも他人のも）。画面はこれで表示を更新する。
signal command_applied(cmd: Dictionary)
## ホストが自分のコマンドを断った（ほかの人の操作が先だったなど）。
signal command_rejected(op: String)
## 状態のずれを検出した（seq = そのコマンドの番号）。
signal desync_detected(seq: int)
signal hosts_changed

enum Role { NONE, HOST, CLIENT }

const PORT: int = 24600
const DISCOVERY_PORT: int = 24601
const MAX_PLAYERS: int = 4
const PROTOCOL: int = 1
const BROADCAST_INTERVAL: float = 1.0
## 自動検出の一覧から消すまでの秒数。
const HOST_TIMEOUT: float = 3.5

var role: Role = Role.NONE
var my_name: String = ""
## 自分の席（ロビーとラン中）。
var seat: int = 0
## 直前の協力プレイのランの席（ランが終わって切れた後の結果画面用。それ以外は 0）。
var last_seat: int = 0
## ロビー：席の順に {peer, name}。
var members: Array[Dictionary] = []
## ラン中（Main が設定する）。null ならロビー。
var run: RunController
## 再開用：ホストが読み込んだ協力プレイのセーブ（null = 新しいラン）。
var resume_save: Dictionary = {}
## LAN 内で見つかったホスト：ip → {name, players, max, in_run, version, seen}。
var hosts: Dictionary[String, Dictionary] = {}
var last_error: String = ""
## テスト用：版の文字列を差し替える（空 = 本物）。
var version_override: String = ""
## 使うポート（テストで差し替える）。
var port: int = PORT
var discovery_port: int = DISCOVERY_PORT
## 前回の名前と参加先の IP（user://coop.cfg）。
var prefs_name: String = ""
var prefs_ip: String = ""

const PREFS_PATH: String = "user://coop.cfg"

var _seq: int = 0
var _req: int = 0
var _callbacks: Dictionary[int, Callable] = {}
var _broadcaster: PacketPeerUDP
var _listener: PacketPeerUDP
var _broadcast_timer: float = 0.0
## 穏やかな切断の途中の ENet（leave の後、CLOSE_GRACE 秒だけ回して相手に届けてから閉じる）。
var _closing: ENetMultiplayerPeer
var _closing_time: float = 0.0

const CLOSE_GRACE: float = 1.0
var _clock: float = 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(false)
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		prefs_name = String(cfg.get_value("coop", "name", ""))
		prefs_ip = String(cfg.get_value("coop", "ip", ""))


func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("coop", "name", prefs_name)
	cfg.set_value("coop", "ip", prefs_ip)
	cfg.save(PREFS_PATH)


func is_active() -> bool:
	return role != Role.NONE


func is_host() -> bool:
	return role == Role.HOST


## ラン中の協力プレイか（画面はこれで、操作を submit するか直接 RunController を呼ぶかを決める）。
func in_run() -> bool:
	return is_active() and run != null


## 版の文字列。ホストと違えば参加できない（コンテンツが違うと同じコマンドでも結果が変わるため）。
func version() -> String:
	if version_override != "":
		return version_override
	var lib := Content.library
	var counts := [lib.cards.size(), lib.relics.size(), lib.potions.size(), lib.enemies.size(), lib.events.size()] \
			if lib != null else []
	return "%s|%d|%s" % [ProjectSettings.get_setting("application/config/version", "0"), PROTOCOL, str(counts)]


## この PC の LAN の IPv4（ホストの画面に出して、参加者に伝えてもらう）。
static func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			result.append(a)
	return result


# —— ホスト / 参加 / 終了 ——

func host(p_name: String) -> bool:
	leave()
	_finish_closing()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		last_error = "ポート %d で待ち受けできませんでした（%s）。ほかの TryCard がホストになっていないか確認してください。" \
				% [port, error_string(err)]
		return false
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	my_name = _clean_name(p_name)
	seat = 0
	members = [{peer = 1, name = my_name}]
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_broadcaster.set_dest_address("255.255.255.255", discovery_port)
	set_process(true)
	lobby_changed.emit()
	Log.info(&"net", "hosting on %d (%s)" % [port, ", ".join(local_addresses())])
	return true


func join(address: String, p_name: String) -> bool:
	leave()
	_finish_closing()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), port)
	if err != OK:
		last_error = "接続できませんでした（%s）" % error_string(err)
		return false
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	my_name = _clean_name(p_name)
	members.clear()
	set_process(true)
	Log.info(&"net", "joining %s:%d" % [address, port])
	return true


## セッションを終える（ロビーから抜ける / ランの後）。自分から抜けるときは session_ended を出さない。
func leave() -> void:
	if role != Role.NONE:
		Log.debug(&"net", "leave (role %d, seq %d)" % [role, _seq])
	_finish_closing()
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and enet.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		# すぐに閉じず、CLOSE_GRACE 秒だけ接続を生かして送受信を回してから閉じる（_process）。直前に配ったコマンドと
		# 切断の通知が相手の同じ受信処理に入ると、相手の ENet は読む前のパケットを捨てる（実測：最後の ack_combat が
		# 届かず、参加者だけ結果画面にならなかった。disconnect_peer の穏やかな切断でも同じだった）。
		_closing = enet
		_closing_time = CLOSE_GRACE
	elif multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	# 終わったランの結果画面が自分の値を出せるよう、ランの席だけ覚えておく（次のロビーで上書きされる）。
	last_seat = seat if run != null and run.is_over() else 0
	role = Role.NONE
	members.clear()
	run = null
	resume_save = {}
	seat = 0
	_seq = 0
	_callbacks.clear()
	if _broadcaster != null:
		_broadcaster.close()
		_broadcaster = null
	set_process(_listener != null or _closing != null)


## 穏やかな切断を待っている ENet を閉じる。
func _finish_closing() -> void:
	if _closing != null:
		_closing.close()
		_closing = null


## 参加画面：LAN 内のホストの検出を始める / 止める。
func start_discovery() -> void:
	if _listener != null:
		return
	_listener = PacketPeerUDP.new()
	var err := _listener.bind(discovery_port)
	if err != OK:
		# 同じ PC で 2 つ目のゲームを開いたときなど。IP の手入力は使える。
		Log.warn(&"net", "discovery bind failed: %s" % error_string(err))
		_listener = null
		return
	hosts.clear()
	set_process(true)


func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
		_listener = null
	hosts.clear()
	set_process(is_active())


# —— ロビー ——

func names() -> PackedStringArray:
	var result := PackedStringArray()
	for m in members:
		result.append(String(m.name))
	return result


## ホスト：ランを始める（新規）。全員の画面を切り替える。
func start_run(seed_value: int) -> void:
	if not is_host():
		return
	var info := {mode = "new", seed = str(seed_value), names = Array(names())}
	_rpc_start.rpc(info)
	_begin(info)


## ホスト：協力プレイのセーブから再開する。人数がセーブと同じであること。
func resume_run(save: Dictionary) -> bool:
	if not is_host():
		return false
	var needed := 1 + (save.get("coop_players", []) as Array).size()
	if needed != members.size():
		last_error = "このセーブは %d 人用です（いま %d 人）" % [needed, members.size()]
		return false
	# セーブの名前と同じ人を同じ席に並べ替える（名前が合わない人は空いた席へ。入った順）。
	var wanted := PackedStringArray([String(save.get("name", ""))])
	for p: Dictionary in save.get("coop_players", []):
		wanted.append(String(p.get("name", "")))
	var rest: Array[Dictionary] = members.duplicate()
	var ordered: Array[Dictionary] = []
	ordered.resize(needed)
	for i in needed:
		for m in rest:
			if String(m.name) == wanted[i]:
				ordered[i] = m
				rest.erase(m)
				break
	for i in needed:
		if ordered[i] == null or ordered[i].is_empty():
			ordered[i] = rest.pop_front()
	# ホストは席 0 のまま（ロックステップの順番を決める役なので）。
	var host_i := ordered.find(members[0])
	if host_i > 0:
		var tmp: Dictionary = ordered[0]
		ordered[0] = ordered[host_i]
		ordered[host_i] = tmp
	members = ordered
	seat = 0
	_send_lobby()
	var info := {mode = "resume", save = save, names = Array(names())}
	_rpc_start.rpc(info)
	_begin(info)
	return true


func _begin(info: Dictionary) -> void:
	_seq = 0
	if _broadcaster != null:
		_broadcast_timer = 0.0
	run_starting.emit(info)


# —— ラン中のコマンド ——

## 自分の操作を送る。ホストなら即座に実行して配る。参加者ならホストに頼み、配られてきたら実行する。
## on_done(ok: bool) は自分のコマンドが適用された（true）/ 断られた（false）ときに 1 回呼ばれる。
func submit(op: StringName, args: Dictionary = {}, on_done: Callable = Callable()) -> void:
	if not in_run():
		if on_done.is_valid():
			on_done.call(false)
		return
	_req += 1
	if on_done.is_valid():
		_callbacks[_req] = on_done
	if is_host():
		_host_execute(seat, String(op), args, _req, 1)
	else:
		_rpc_request.rpc_id(1, String(op), args, _req)


func _host_execute(from_seat: int, op: String, args: Dictionary, req: int, peer: int) -> void:
	var cmd := CoopCommands.make(from_seat, StringName(op), args)
	if not CoopCommands.apply(run, cmd):
		if peer == 1:
			_finish_request(req, false)
			command_rejected.emit(op)
		else:
			_rpc_rejected.rpc_id(peer, req, op)
		return
	_seq += 1
	cmd.seq = _seq
	cmd.req = req
	cmd.hash = CoopCommands.digest(run)
	_rpc_command.rpc(cmd)
	Log.debug(&"net", "sent %d %s seat %d (phase %s)" % [_seq, op, from_seat, RunPhase.Id.keys()[run.state.phase]])
	if peer == 1:
		_finish_request(req, true)
	command_applied.emit(cmd)


func _finish_request(req: int, ok: bool) -> void:
	var cb: Callable = _callbacks.get(req, Callable())
	_callbacks.erase(req)
	if cb.is_valid():
		cb.call(ok)


# —— RPC ——

@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(p_name: String, p_version: String) -> void:
	if not is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	if p_version != version():
		_rpc_refused.rpc_id(peer, "ゲームの版が違います（ホスト：%s）" % version())
		return
	if run != null:
		_rpc_refused.rpc_id(peer, "ホストはすでにプレイ中です")
		return
	if members.size() >= MAX_PLAYERS:
		_rpc_refused.rpc_id(peer, "満員です（%d 人まで）" % MAX_PLAYERS)
		return
	members.append({peer = peer, name = _unique_name(_clean_name(p_name))})
	_send_lobby()


@rpc("authority", "call_remote", "reliable")
func _rpc_refused(reason: String) -> void:
	var r := reason
	leave()
	last_error = r
	session_ended.emit(r)


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(list: Array) -> void:
	members.clear()
	for m: Dictionary in list:
		members.append(m)
	seat = 0
	for i in members.size():
		if int(members[i].peer) == multiplayer.get_unique_id():
			seat = i
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_start(info: Dictionary) -> void:
	_begin(info)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(op: String, args: Dictionary, req: int) -> void:
	if not is_host() or run == null:
		return
	var peer := multiplayer.get_remote_sender_id()
	var from_seat := _seat_of_peer(peer)
	if from_seat < 0:
		return
	_host_execute(from_seat, op, args, req, peer)


@rpc("authority", "call_remote", "reliable")
func _rpc_command(cmd: Dictionary) -> void:
	if run == null:
		return
	var seq := int(cmd.get("seq", 0))
	if seq != _seq + 1:
		Log.warn(&"net", "command out of order: got %d after %d" % [seq, _seq])
		desync_detected.emit(seq)
	_seq = seq
	var ok := CoopCommands.apply(run, cmd)
	Log.debug(&"net", "cmd %d %s seat %s -> %s (phase %s)" % [seq, cmd.get("op"), cmd.get("seat"), ok,
			RunPhase.Id.keys()[run.state.phase]])
	var mine := int(cmd.get("seat", -1)) == seat
	if not ok or CoopCommands.digest(run) != int(cmd.get("hash", 0)):
		Log.warn(&"net", "desync at %d (%s, applied=%s)" % [seq, cmd.get("op"), ok])
		desync_detected.emit(seq)
	if mine:
		_finish_request(int(cmd.get("req", 0)), ok)
	command_applied.emit(cmd)


@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(req: int, op: String) -> void:
	_finish_request(req, false)
	command_rejected.emit(op)


@rpc("authority", "call_remote", "reliable")
func _rpc_closed(reason: String) -> void:
	var r := reason
	leave()
	session_ended.emit(r)


# —— 接続のイベント ——

func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	var i := _seat_of_peer(id)
	if i < 0:
		return
	var who := String(members[i].name)
	if run != null and run.is_over():
		return   # ランが終わった後（結果画面からメニューへ戻った）なら正常な終了
	if run != null:
		# ラン中に抜けたら全員を止める（ホストのセーブから再開する。GameDesign §21）。
		var reason := "%s さんの接続が切れました。ホストの「協力プレイ → 続きから」で再開できます。" % who
		_rpc_closed.rpc(reason)
		leave()
		session_ended.emit(reason)
		return
	members.remove_at(i)
	_send_lobby()


func _on_connected_to_server() -> void:
	_rpc_hello.rpc_id(1, my_name, version())


func _on_connection_failed() -> void:
	leave()
	last_error = "ホストに接続できませんでした。IP アドレスと、ホストのファイアウォールの許可を確認してください。"
	session_ended.emit(last_error)


func _on_server_disconnected() -> void:
	var was_in_run := run != null
	Log.debug(&"net", "server disconnected (in run: %s, over: %s)" % [was_in_run, was_in_run and run.is_over()])
	if was_in_run and run.is_over():
		# ホストが結果画面からメニューへ戻っただけ。こちらの結果画面はそのまま（Main は終わったランでは何もしない）。
		leave()
		return
	leave()
	last_error = "ホストとの接続が切れました。" + ("ホストの「続きから」で再開できます。" if was_in_run else "")
	session_ended.emit(last_error)


# —— 内部 ——

func _process(delta: float) -> void:
	_clock += delta
	if _closing != null:
		_closing.poll()
		_closing_time -= delta
		if _closing_time <= 0.0:
			_finish_closing()
			set_process(_listener != null or is_active())
	if _broadcaster != null and run == null:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = BROADCAST_INTERVAL
			var msg := JSON.stringify({game = "TryCard", name = my_name, players = members.size(), max = MAX_PLAYERS,
					version = version()})
			_broadcaster.put_packet(msg.to_utf8_buffer())
	if _listener != null:
		var changed := false
		while _listener.get_available_packet_count() > 0:
			var data := _listener.get_packet().get_string_from_utf8()
			var ip := _listener.get_packet_ip()
			var parsed: Variant = JSON.parse_string(data)
			if parsed is Dictionary and (parsed as Dictionary).get("game") == "TryCard" and ip != "":
				var info: Dictionary = parsed
				info.seen = _clock
				changed = changed or not hosts.has(ip)
				hosts[ip] = info
		for ip: String in hosts.keys():
			if _clock - float(hosts[ip].seen) > HOST_TIMEOUT:
				hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()


func _send_lobby() -> void:
	_rpc_lobby.rpc(members)
	lobby_changed.emit()


func _seat_of_peer(peer: int) -> int:
	for i in members.size():
		if int(members[i].peer) == peer:
			return i
	return -1


func _clean_name(n: String) -> String:
	var s := n.strip_edges().substr(0, 12)
	return s if s != "" else "プレイヤー"


func _unique_name(n: String) -> String:
	var taken := names()
	if not taken.has(n):
		return n
	var i := 2
	while taken.has("%s%d" % [n, i]):
		i += 1
	return "%s%d" % [n, i]

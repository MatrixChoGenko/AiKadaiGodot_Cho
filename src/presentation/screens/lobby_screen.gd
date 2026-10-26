class_name LobbyScreen extends PanelScreen
## ⑤ Presentation：協力プレイのロビー（GameDesign §21）。メインメニューの「協力プレイ」から。
## - 接続前：名前の入力、「ホストになる」（新しいラン / 続きから）、LAN 内で見つかったホストの一覧、IP の手入力で「参加」。
## - 接続後：席の一覧。ホストは自分の IP を表示し、2 人以上そろったら「開始」。参加者はホストの開始を待つ。
## ランが始まると Net.run_starting を受けた Main が画面を切り替える。抜けるときは Net.leave()。

signal back_requested

const BACKDROP: Texture2D = preload("res://assets/textures/backgrounds/title_campfire.jpg")
## 一覧の見出しなどの色。
const DIM_COLOR: Color = Color(0.78, 0.74, 0.66)
const ERROR_COLOR: Color = Color(1.0, 0.62, 0.5)

## 前の画面から渡された案内（切断の理由など）。
var message: String = ""

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _hosts_box: VBoxContainer
var _status: Label


func _init() -> void:
	panel_width = 980.0
	backdrop_image = BACKDROP
	show_top_bar = false


func enter(args: Dictionary) -> void:
	super.enter(args)
	message = String(args.get(&"message", ""))
	Net.lobby_changed.connect(rebuild)
	Net.hosts_changed.connect(_refresh_hosts)
	Net.session_ended.connect(_on_session_ended)
	title_label.text = "協力プレイ（LAN）"
	rebuild()


func exit() -> void:
	Net.lobby_changed.disconnect(rebuild)
	Net.hosts_changed.disconnect(_refresh_hosts)
	Net.session_ended.disconnect(_on_session_ended)
	Net.stop_discovery()


func rebuild() -> void:
	clear_body()
	clear_footer()
	_hosts_box = null
	if Net.is_active():
		_build_room()
	else:
		_build_entry()
	if message != "":
		var m := add_text(message, true)
		m.add_theme_color_override(&"font_color", ERROR_COLOR)


# —— 接続前 ——

func _build_entry() -> void:
	Net.start_discovery()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	var label := Label.new()
	label.text = "あなたの名前"
	row.add_child(label)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(320, 52)
	_name_edit.max_length = 12
	_name_edit.text = Net.prefs_name
	_name_edit.placeholder_text = "12 文字まで"
	row.add_child(_name_edit)
	body.add_child(row)

	var host_row := HBoxContainer.new()
	host_row.alignment = BoxContainer.ALIGNMENT_CENTER
	host_row.add_theme_constant_override(&"separation", 16)
	body.add_child(host_row)
	add_button("ホストになる（新しいラン）", host_new, host_row, &"ButtonPrimary")
	if SaveManager.has_coop_run():
		add_button("ホストになる（続きから）", host_resume, host_row)

	var head := add_text("LAN 内のホスト（見つかると自動で並びます）", true)
	head.add_theme_color_override(&"font_color", DIM_COLOR)
	_hosts_box = VBoxContainer.new()
	_hosts_box.add_theme_constant_override(&"separation", 8)
	body.add_child(_hosts_box)
	_refresh_hosts()

	var ip_row := HBoxContainer.new()
	ip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ip_row.add_theme_constant_override(&"separation", 12)
	var ip_label := Label.new()
	ip_label.text = "IP を入力して参加"
	ip_row.add_child(ip_label)
	_ip_edit = LineEdit.new()
	_ip_edit.custom_minimum_size = Vector2(300, 52)
	_ip_edit.text = Net.prefs_ip
	_ip_edit.placeholder_text = "例：172.16.51.93"
	_ip_edit.text_submitted.connect(func(_t: String) -> void: join_ip())
	ip_row.add_child(_ip_edit)
	add_button("参加", join_ip, ip_row)
	body.add_child(ip_row)

	add_button("戻る", _on_back, footer)


func _refresh_hosts() -> void:
	if _hosts_box == null:
		return
	for child in _hosts_box.get_children():
		child.queue_free()
	if Net.hosts.is_empty():
		var none := Label.new()
		none.text = "（まだ見つかりません。ホストの PC と同じネットワークか、IP の手入力を試してください）"
		none.theme_type_variation = &"LabelSmall"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override(&"font_color", DIM_COLOR)
		_hosts_box.add_child(none)
		return
	var ips := Net.hosts.keys()
	ips.sort()
	for ip: String in ips:
		var h: Dictionary = Net.hosts[ip]
		var same := String(h.get("version", "")) == Net.version()
		var text := "%s の部屋（%d/%d 人）　%s" % [h.get("name", "?"), int(h.get("players", 0)), int(h.get("max", 4)), ip]
		if not same:
			text += "　※ゲームの版が違います"
		var b := add_button(text, join.bind(ip), _hosts_box)
		b.disabled = not same


func host_new() -> void:
	_remember()
	if not Net.host(_name_edit.text):
		_show_error(Net.last_error)
		return
	Net.resume_save = {}
	message = ""
	rebuild()


func host_resume() -> void:
	var save := SaveManager.load_coop_dict()
	if save.is_empty():
		_show_error("協力プレイのセーブを読み込めませんでした")
		return
	_remember()
	if not Net.host(_name_edit.text):
		_show_error(Net.last_error)
		return
	Net.resume_save = save
	message = ""
	rebuild()


func join_ip() -> void:
	join(_ip_edit.text)


func join(ip: String) -> void:
	if ip.strip_edges() == "":
		_show_error("IP アドレスを入力してください")
		return
	_remember(ip)
	if not Net.join(ip, _name_edit.text):
		_show_error(Net.last_error)
		return
	message = ""
	rebuild()


# —— 接続後 ——

func _build_room() -> void:
	if Net.is_host():
		var ips := Net.local_addresses()
		add_text("参加する人に、この PC の IP を伝えてください：%s" % ("、".join(ips) if not ips.is_empty() else "（不明）"))
		if not Net.resume_save.is_empty():
			var need := 1 + (Net.resume_save.get("coop_players", []) as Array).size()
			add_text("続きから：このセーブは %d 人用です（%s）" % [need, "、".join(_save_names())], true)
	elif Net.members.is_empty():
		add_text("ホストに接続しています…")
	else:
		add_text("ホストが開始するのを待っています…")
	for i in Net.members.size():
		var m: Dictionary = Net.members[i]
		var line := add_text("%d. %s%s%s" % [i + 1, m.name, "（ホスト）" if i == 0 else "", "　← あなた" if i == Net.seat else ""])
		line.add_theme_color_override(&"font_color", Party.color(i))
	for i in range(Net.members.size(), Net.MAX_PLAYERS):
		var empty := add_text("%d. （空き）" % (i + 1), true)
		empty.add_theme_color_override(&"font_color", DIM_COLOR)
	if Net.is_host():
		var start := add_button("開始", start_run, footer, &"ButtonPrimary")
		start.disabled = Net.members.size() < 2
		if start.disabled:
			start.tooltip_text = "開始\n2 人以上そろうと開始できます。"
	add_button("抜ける", _on_leave, footer)


## ホスト：ランを始める（続きからならセーブから）。
func start_run() -> void:
	if not Net.is_host():
		return
	if not Net.resume_save.is_empty():
		if not Net.resume_run(Net.resume_save):
			_show_error(Net.last_error)
		return
	Net.start_run(randi())


func _save_names() -> PackedStringArray:
	var result := PackedStringArray([String(Net.resume_save.get("name", "?"))])
	for p: Dictionary in Net.resume_save.get("coop_players", []):
		result.append(String(p.get("name", "?")))
	return result


# —— 共通 ——

func _remember(ip: String = "") -> void:
	if _name_edit != null:
		Net.prefs_name = _name_edit.text.strip_edges()
	if ip != "":
		Net.prefs_ip = ip.strip_edges()
	Net.save_prefs()


func _show_error(text: String) -> void:
	message = text
	rebuild()


func _on_session_ended(reason: String) -> void:
	message = reason
	rebuild()


func _on_leave() -> void:
	Net.leave()
	message = ""
	rebuild()


func _on_back() -> void:
	Net.leave()
	back_requested.emit()

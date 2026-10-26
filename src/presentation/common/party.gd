class_name Party extends RefCounted
## ⑤ Presentation：画面からランを操作するときの窓口（協力プレイ。GameDesign §21 / Architecture §23）。
## 画面は RunController / CombatController のコマンドを直接呼ばず、ここに CoopCommands の形で渡す。
## - 1 人プレイ：その場で CoopCommands.apply() して on_done(ok) を呼ぶ（同期。従来と同じ流れ）。
## - 協力プレイ：Net.submit() でホストへ送り、全員の状態に適用されたときに on_done(true)、断られたら on_done(false)。
## 表示に使う「自分」のプレイヤー / 席も ここで引く（RunState.active や Combat.seat はルール側の処理用なので使わない）。


## プレイヤーごとの色（名前・投票・味方の HP の印。席の番号順）。
const COLORS: Array[Color] = [Color(1.0, 0.85, 0.4), Color(0.55, 0.85, 1.0), Color(0.6, 1.0, 0.6), Color(1.0, 0.6, 0.85)]


static func color(seat_index: int) -> Color:
	return COLORS[posmod(seat_index, COLORS.size())]


## 協力プレイのラン中か。
static func coop() -> bool:
	return Net.in_run()


## 自分の席の番号（1 人プレイでは 0）。ランが終わってホストとの接続が切れた後も、結果画面のために席を覚えている。
static func seat() -> int:
	return Net.seat if coop() else Net.last_seat


## 自分のプレイヤー（ラン）。
static func me(run: RunController) -> PlayerState:
	return run.player(seat())


## 自分の席（戦闘）。
static func my_seat(ctl: CombatController) -> PlayerSeat:
	var s := ctl.seat_at(seat())
	return s if s != null else ctl.seat_at(0)


## ランのコマンドを出す。on_done(ok: bool)。
static func act(run: RunController, op: StringName, args: Dictionary = {}, on_done: Callable = Callable()) -> void:
	if coop():
		Net.submit(op, args, on_done)
		return
	var ok := CoopCommands.apply(run, CoopCommands.make(0, op, args))
	if on_done.is_valid():
		on_done.call(ok)


## 戦闘のコマンドを出す（run が null = サンドボックスの戦闘）。on_done(ok: bool)。
static func act_combat(run: RunController, ctl: CombatController, op: StringName, args: Dictionary = {},
		on_done: Callable = Callable()) -> void:
	if coop() and run != null:
		Net.submit(op, args, on_done)
		return
	var ok := CoopCommands.apply_combat(ctl, 0, op, args)
	if on_done.is_valid():
		on_done.call(ok)

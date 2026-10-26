class_name HandInput extends Node
## ⑤ Presentation：手札の入力のステートマシン（Architecture §14.4、U05）。View の signal とマウスをコマンドに翻訳する。
##   IDLE ─カードを押す─▶ DRAG（対象不要）─プレイラインを越えて離す─▶ play_card()
##                         │                └─動かさずに離す─▶ SELECTED ─プレイラインより上をクリック─▶ play_card()
##                         └─（対象が必要）─▶ AIM（矢印）─敵の上で離す / 敵をクリック─▶ play_card(target)
##   ポーション（対象が必要）─▶ POTION_AIM ─敵をクリック─▶ use_potion(slot, target)
## 右クリック / Esc で取り消す。ロック（敵のターン・再生中・カード選択中・戦闘終了）は CombatScreen.can_act() が決める。

enum State { IDLE, DRAG, AIM, SELECTED, POTION_AIM }

const CLICK_DISTANCE: float = 14.0

var state: State = State.IDLE
var view: CardView
var potion_slot: int = -1

var _screen: CombatScreen
var _press_pos: Vector2 = Vector2.ZERO
var _moved: bool = false
var _target: Combatant


func bind(screen: CombatScreen) -> void:
	_screen = screen
	screen.hand.card_pressed.connect(_on_card_pressed)


## 照準中の敵（カードテキストの対象として使う）。
func aim_target() -> Combatant:
	return _target if state in [State.AIM, State.POTION_AIM] else null


func cancel() -> void:
	if view != null and is_instance_valid(view):
		_screen.hand.clear_held()
	view = null
	potion_slot = -1
	state = State.IDLE
	_set_target(null)
	_screen.arrow.visible = false


## ポーションの照準を始める（対象が必要なポーション）。
func begin_potion_aim(slot: int) -> void:
	cancel()
	potion_slot = slot
	state = State.POTION_AIM
	_moved = true   # 次のクリックで決める
	_update_arrow(_mouse())


func _on_card_pressed(v: CardView) -> void:
	if state == State.SELECTED and v == view:
		_play(null)
		return
	cancel()
	if not _screen.can_play():
		_screen.request_fast_forward()
		return
	var r := _screen.ctl.check_card(v.card, null)
	if not r.ok and r.reason != PlayResult.NEED_TARGET:
		_screen.toast(UiText.play_reason(r.reason), v.global_position + v.size / 2.0)
		return
	view = v
	_press_pos = _mouse()
	_moved = false
	if _screen.ctl.needs_target(v.card):
		state = State.AIM
		_screen.hand.set_held(v, _aim_origin_center())
		_update_arrow(_press_pos)
	else:
		state = State.DRAG
		_screen.hand.set_held(v, _press_pos)


func _input(event: InputEvent) -> void:
	if state == State.IDLE or _screen == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var pos := _mouse()
		if pos.distance_to(_press_pos) > CLICK_DISTANCE:
			_moved = true
		match state:
			State.DRAG:
				_screen.hand.set_held(view, pos)
			State.AIM, State.POTION_AIM:
				_update_arrow(pos)
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		if event.is_action_pressed(&"ui_cancel"):
			cancel()
			get_viewport().set_input_as_handled()
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		cancel()
		get_viewport().set_input_as_handled()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos := _mouse()
	if mb.pressed:
		match state:
			State.AIM, State.POTION_AIM:
				# 2 段階操作の 2 回目のクリック：敵の上ならプレイ、それ以外なら取り消し。
				var t := _screen.enemy_at(pos)
				get_viewport().set_input_as_handled()
				if t != null:
					_play(t)
				else:
					cancel()
			State.SELECTED:
				if pos.y < _screen.play_line_y():
					get_viewport().set_input_as_handled()
					_play(null)
		return
	match state:
		State.DRAG:
			if _moved and pos.y < _screen.play_line_y():
				_play(null)
			elif not _moved:
				state = State.SELECTED
				_screen.hand.set_held(view, _aim_origin_center())
			else:
				cancel()
		State.AIM:
			if not _moved:
				return   # クリックで照準を始めた。次のクリックを待つ
			var t := _screen.enemy_at(pos)
			if t != null:
				_play(t)
			else:
				cancel()


func _play(target: Combatant) -> void:
	if state == State.POTION_AIM:
		var slot := potion_slot
		cancel()
		_screen.try_use_potion(slot, target)
		return
	var card := view.card if view != null else null
	var v := view
	view = null
	state = State.IDLE
	_set_target(null)
	_screen.arrow.visible = false
	if card == null or not _screen.try_play(card, target):
		if v != null and is_instance_valid(v):
			_screen.hand.clear_held()


func _update_arrow(pos: Vector2) -> void:
	var t := _screen.enemy_at(pos)
	_set_target(t)
	# 矢印の根元は持ち上げたカードの目標位置（補間中の現在位置ではなく）の上端あたり。
	var from := _screen.potion_origin() if state == State.POTION_AIM \
			else _screen.hand.global_position + view.target_center + Vector2(0, -110)
	_screen.arrow.point(from, pos, t != null)


func _set_target(t: Combatant) -> void:
	if t == _target:
		return
	if _target != null and _screen.unit_view(_target.uid) != null:
		_screen.unit_view(_target.uid).set_targeted(false)
	_target = t
	if t != null and _screen.unit_view(t.uid) != null:
		_screen.unit_view(t.uid).set_targeted(true)


## 持ち上げたカードを置く位置（手札の中央の上）。
func _aim_origin_center() -> Vector2:
	var h := _screen.hand
	return h.global_position + Vector2(h.size.x / 2.0, h.size.y - HandView.HOVER_FROM_BOTTOM - 40.0)


func _mouse() -> Vector2:
	return _screen.get_global_mouse_position()

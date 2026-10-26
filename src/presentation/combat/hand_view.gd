class_name HandView extends Control
## ⑤ Presentation：手札（Architecture §14.3、U05）。扇形の配置とホバーだけを担い、プレイの判断は HandInput が行う。
## 手札の View は piles.hand を直接写さない。Presenter が CARD_DRAWN などを再生した時点で 1 枚ずつ add_card / take する。
## 再生の後に Presenter が sync() でモデルの手札と突き合わせ、ずれを直す。

signal card_pressed(view: CardView)

const CARD_SCENE: PackedScene = preload("res://scenes/widgets/card_view.tscn")
const HAND_SCALE: float = 0.78
## 手札からの拡大量（1.08 - 0.78）を 25% 減らした値（2026-10-21、ユーザー指定）。
const HOVER_SCALE: float = 1.005
## 手札の基準点（カードの中心）の、下端からの高さ。
## カードの下端は画面の外へ沈める（上端を敵の足元の状態異常アイコンより下に保つ）。
const BASE_FROM_BOTTOM: float = 116.0
const HOVER_FROM_BOTTOM: float = 261.0
const HOVER_PUSH: float = 72.0
## 出したカードが行き先（対象 / 場の中央）へ飛ぶ秒。着いた所で CardBurst が弾ける。
const PLAY_FLIGHT: float = 0.22
## ターン終了の捨て札（&"burn"。StS2 の録画に合わせた）：持ち上げる量・傾き・縮んだ大きさ・弧の高さ（px）・飛ぶ秒。
const BURN_LIFT: float = 30.0
const BURN_TILT_DEG: float = 13.0
const BURN_CHIP_SCALE: float = 0.14
const BURN_ARC_HEIGHT: float = 820.0
const BURN_FLIGHT: float = 0.75

## 持ち上げ中（ドラッグ / クリックで選択中）のカード。配置の計算から外す。
var held: CardView
var held_center: Vector2 = Vector2.ZERO
var hovered: CardView

var _views: Array[CardView] = []


func views() -> Array[CardView]:
	return _views


func view_of(uid: int) -> CardView:
	for v in _views:
		if v.card.uid == uid:
			return v
	return null


## カードを手札に加える（from_global から飛んでくる）。
func add_card(card: Card, text: String, cost: int, from_global: Vector2) -> CardView:
	var v := CARD_SCENE.instantiate() as CardView
	add_child(v)
	v.show_card(card.data, text, card, cost)
	v.place_center(from_global - global_position)
	v.scale = Vector2.ONE * 0.25
	v.reveal_from_back()
	v.follow = true
	v.pressed.connect(_on_view_pressed)
	v.hover_changed.connect(_on_view_hover_changed)
	_views.append(v)
	relayout()
	return v


## カードを手札の配置から外して返す（見つからなければ null）。返した View は release() で片付ける。
func take(uid: int) -> CardView:
	var v := view_of(uid)
	if v == null:
		return null
	_views.erase(v)
	if hovered == v:
		hovered = null
	if held == v:
		held = null
		v.set_selected(false)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relayout()
	return v


## 手札から離れたカードを飛ばして消す。style：&"play"（対象へ飛んで消える）/ &"pile"（山へ縮んで飛ぶ）/ &"exhaust"（その場で燃えて消える）
## / &"burn"（ターン終了の捨て札。焦げて縮み、炎の尾を引いて弧を描いて山へ）。
func release(v: CardView, to_global: Vector2, style: StringName) -> void:
	v.follow = false
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_playable(false)
	v.z_index = 120
	var to := to_global - global_position - v.size / 2.0
	var t := v.create_tween()
	match style:
		&"play":
			t.set_parallel(true)
			t.tween_property(v, "position", to, PLAY_FLIGHT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(v, "rotation", 0.0, PLAY_FLIGHT)
			t.tween_property(v, "scale", Vector2.ONE * 0.9, PLAY_FLIGHT)
			t.chain().tween_property(v, "modulate:a", 0.0, 0.18)
		&"exhaust":
			t.set_parallel(true)
			t.tween_property(v, "modulate", Color(1.0, 0.35, 0.2, 0.0), 0.4)
			t.tween_property(v, "scale", v.scale * 1.15, 0.4)
		&"burn":
			# 持ち上げて傾け、焦げた色に → 小さく縮む → 炎の尾（EmberTrail）を引いて弧を描き、山へ落ちる。
			var lifted := v.position + Vector2(0, -BURN_LIFT)
			t.set_parallel(true)
			t.tween_property(v, "position", lifted, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(v, "rotation", v.rotation + deg_to_rad(BURN_TILT_DEG), 0.15)
			t.tween_property(v, "modulate", Color(0.6, 0.38, 0.28), 0.15)
			t.chain().tween_property(v, "scale", Vector2.ONE * BURN_CHIP_SCALE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(v, "modulate", Color(0.35, 0.2, 0.15), 0.12)
			t.chain().tween_callback(func() -> void: EmberTrail.follow(v, self))
			t.chain().tween_method(_burn_arc.bind(v, {}, to_global - global_position), 0.0, 1.0, BURN_FLIGHT)
			t.chain().tween_property(v, "modulate:a", 0.0, 0.05)
		_:
			t.set_parallel(true)
			t.tween_property(v, "position", to, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_property(v, "scale", Vector2.ONE * 0.2, 0.3)
			t.tween_property(v, "modulate:a", 0.0, 0.3).set_delay(0.1)
	t.chain().tween_callback(v.queue_free)


## &"burn" の飛行：見た目の中心を p0（飛び始めの位置。flight に覚える）→ p2 の 2 次ベジェ曲線で動かす
## （制御点は高く上げ、山の手前で急降下する）。u は後半ほど速く進める。
func _burn_arc(u: float, v: CardView, flight: Dictionary, p2: Vector2) -> void:
	var c := visual_center(v)
	if not flight.has(&"p0"):
		flight[&"p0"] = c
	var p0: Vector2 = flight[&"p0"]
	var p1 := Vector2(lerpf(p0.x, p2.x, 0.45), minf(p0.y, p2.y) - BURN_ARC_HEIGHT)
	var k := ease(u, 1.4)
	var pos := p0.lerp(p1, k).lerp(p1.lerp(p2, k), k)
	var dir := pos - c
	if dir.length_squared() > 0.01:
		v.rotation = lerp_angle(v.rotation, dir.angle() + PI / 2.0, 0.25)
	v.position += pos - visual_center(v)


## カードの見た目の中心（手札の座標。回転・縮小・pivot を含む）。
func visual_center(v: CardView) -> Vector2:
	return v.get_global_transform() * (v.size / 2.0) - global_position


## モデルの手札と突き合わせる（足りないカードは from_global から足し、余分なカードは消す。順番も合わせる）。
## face：func(card: Card) -> Array（[text, cost]）。
func sync(cards: Array[Card], face: Callable, from_global: Vector2) -> void:
	for v in _views.duplicate():
		if not cards.has(v.card):
			release(take(v.card.uid), v.global_position + v.size / 2.0, &"exhaust")
	var ordered: Array[CardView] = []
	for c in cards:
		var v := view_of(c.uid)
		if v == null:
			var f: Array = face.call(c)
			v = add_card(c, f[0], f[1], from_global)
		ordered.append(v)
	_views = ordered
	relayout()


## 持ち上げ中のカードは金色に光らせる。
func set_held(v: CardView, center_global: Vector2) -> void:
	if held != null and held != v:
		held.set_selected(false)
	held = v
	v.set_selected(true)
	v.hide_tips()
	held_center = center_global - global_position
	relayout()


func clear_held() -> void:
	if held != null:
		held.set_selected(false)
	held = null
	relayout()


func relayout() -> void:
	var n := _views.size()
	var base := Vector2(size.x / 2.0, size.y - BASE_FROM_BOTTOM)
	var h := _views.find(hovered) if held == null else -1
	for i in n:
		var v := _views[i]
		var o := HandLayout.compute(i, n)
		var c := base + Vector2(o.x, o.y)
		var rot := o.z
		var s := HAND_SCALE
		var z := i
		if v == held:
			c = held_center
			rot = 0.0
			s = HOVER_SCALE
			z = 100
		elif h >= 0:
			if i == h:
				c = Vector2(c.x, size.y - HOVER_FROM_BOTTOM)
				rot = 0.0
				s = HOVER_SCALE
				z = 90
			else:
				c.x += signf(i - h) * HOVER_PUSH / absf(i - h)
		v.target_center = c
		v.target_rotation = rot
		v.target_scale = s
		v.z_index = z


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		relayout()


func _on_view_pressed(v: CardView) -> void:
	card_pressed.emit(v)


func _on_view_hover_changed(v: CardView, on: bool) -> void:
	if on:
		hovered = v
	elif hovered == v:
		hovered = null
	if held == null:
		relayout()

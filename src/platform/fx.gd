extends Node
## ① Platform / Autoload `Fx`：エフェクトシーンのオブジェクトプール（Architecture §15.1）。
## `Fx.spawn(&"floating_number", global_pos, {text = "12", color = Color.RED})`。エフェクトは自前の CanvasLayer（10）に出す。
## 画面切り替え時に Main が clear() を呼ぶ。M4 はフローティング数字だけ。残りのエフェクトは M6 で追加する。
## 戦闘のキャラクターに付く 3D のエフェクト（被弾・ブロック・死亡）は Fx ではなく BattleStage.spawn_fx。

const SCENES: Dictionary[StringName, PackedScene] = {
	&"floating_number": preload("res://scenes/fx/floating_number.tscn"),
	&"card_burst": preload("res://scenes/fx/card_burst.tscn"),
	&"victory": preload("res://scenes/fx/victory.tscn"),
}
const LAYER: int = 10

var _layer: CanvasLayer
var _pool: Dictionary[StringName, Array] = {}


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)


func spawn(kind: StringName, global_pos: Vector2, args: Dictionary = {}) -> FxNode:
	var scene: PackedScene = SCENES.get(kind)
	if scene == null:
		Log.warn(&"fx", "unknown fx: %s" % kind)
		return null
	var free_list: Array = _pool.get_or_add(kind, [])
	var node: FxNode
	if free_list.is_empty():
		node = scene.instantiate() as FxNode
		node.kind = kind
		node.finished.connect(_on_fx_finished.bind(node))
		_layer.add_child(node)
	else:
		node = free_list.pop_back()
	node.visible = true
	node.play(global_pos, args)
	return node


## 再生中のエフェクトをすべて止めてプールに戻す。
func clear() -> void:
	if _layer == null:
		return
	for child in _layer.get_children():
		var node := child as FxNode
		if node != null and node.visible:
			node.stop()


## 再生中の数（テスト用）。
func active_count() -> int:
	var n := 0
	for child in _layer.get_children():
		if (child as CanvasItem).visible:
			n += 1
	return n


func _on_fx_finished(node: FxNode) -> void:
	node.visible = false
	(_pool.get_or_add(node.kind, []) as Array).append(node)

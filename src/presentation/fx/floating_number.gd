class_name FloatingNumber extends FxNode
## ⑤ Presentation：フローティング数字（GameDesign §16.2）。args：text、color、scale（1.0 = 標準）。
## 打撃の重さに応じた大きさ・揺れなどは M6 で足す。

const RISE: float = 80.0
const DURATION: float = 0.9

@onready var _label: Label = %Label


func play(global_pos: Vector2, args: Dictionary) -> void:
	_label.text = args.get(&"text", "")
	_label.modulate = args.get(&"color", Color.WHITE)
	var s: float = args.get(&"scale", 1.0)
	scale = Vector2.ONE * s
	modulate.a = 1.0
	_label.reset_size()
	size = _label.size
	pivot_offset = size / 2.0
	global_position = global_pos - size / 2.0
	var t := _new_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", position.y - RISE, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, DURATION * 0.4).set_delay(DURATION * 0.6)
	t.chain().tween_callback(stop)

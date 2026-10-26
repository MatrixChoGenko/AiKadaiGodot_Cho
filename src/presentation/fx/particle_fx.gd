class_name ParticleFx extends FxNode
## ⑤ Presentation：子の GPUParticles2D を一斉に出す 2D のエフェクト（Fx のプールで使い回す。card_burst / victory）。
## args：color（tinted に挙げた子を染める）、delay（秒。待ってから出す）。いちばん長い寿命が過ぎたらプールに戻る。
## 見た目の調整は scenes/fx/*.tscn を開いて Inspector で行う。

## 色を付ける子の名前（挙げない子は白のまま。例：カードの光の白い芯）。
@export var tinted: Array[StringName] = []


func play(global_pos: Vector2, args: Dictionary) -> void:
	global_position = global_pos
	_place()
	var color: Color = args.get(&"color", Color.WHITE)
	var longest := 0.0
	for p in particles():
		p.emitting = false
		p.modulate = color if tinted.has(p.name) else Color.WHITE
		longest = maxf(longest, p.lifetime)
	var t := _new_tween()
	t.tween_interval(args.get(&"delay", 0.0))
	t.tween_callback(_burst)
	t.tween_interval(longest)
	t.tween_callback(stop)


func particles() -> Array[GPUParticles2D]:
	var list: Array[GPUParticles2D] = []
	for c in get_children():
		if c is GPUParticles2D:
			list.append(c)
	return list


## 出す前に子の配置を決める（画面全体に出すエフェクトが上書きする）。
func _place() -> void:
	pass


func _burst() -> void:
	for p in particles():
		p.restart()

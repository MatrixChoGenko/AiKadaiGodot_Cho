class_name VictoryFx extends ParticleFx
## ⑤ Presentation：勝利の紙吹雪と光の粒（画面全体）。左右の下の角から紙吹雪を打ち上げ、下辺から光の粒が昇る。
## 位置は play の global_pos を使わず、画面（ビューポート）の大きさから決める。


func _place() -> void:
	global_position = Vector2.ZERO
	var size := get_viewport_rect().size
	(get_node("CannonLeft") as Node2D).position = Vector2(0.0, size.y)
	(get_node("CannonRight") as Node2D).position = Vector2(size.x, size.y)
	(get_node("Sparkles") as Node2D).position = Vector2(size.x / 2.0, size.y)

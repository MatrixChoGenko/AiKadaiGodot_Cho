extends Node
## ① Platform / Autoload `TimeFx`：ヒットストップ / スローモーション（Engine.time_scale）。
## 実時間で計測し、必ず元に戻す。M0 では reset() のみ。M6 で hit_stop / slow_motion を実装する（Architecture §15.2）。


## time_scale を既定値に戻す。画面切り替え時に Main から呼ぶ。
func reset() -> void:
	Engine.time_scale = 1.0

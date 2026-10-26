class_name HandLayout extends RefCounted
## ⑤ Presentation：扇形の手札の配置（Architecture §14.3）。純粋関数。
## 横は等間隔（枚数が多いと間隔を詰める）、縦は放物線状に沈め、角度は線形補間する。

const SPACING: float = 185.0
const MAX_WIDTH: float = 1150.0
const SAG: float = 34.0
const MAX_ANGLE_DEG: float = 11.0


## i 枚目（0 始まり）/ n 枚の、手札の基準点からのずれ（x, y）と回転（z、ラジアン）。
static func compute(i: int, n: int, max_width: float = MAX_WIDTH) -> Vector3:
	if n <= 1:
		return Vector3.ZERO
	var spacing := minf(SPACING, max_width / float(n - 1))
	var mid := (n - 1) / 2.0
	var t := (i - mid) / mid      # -1 〜 1
	var spread := clampf(n / 7.0, 0.35, 1.0)   # 少ない枚数ではあまり曲げない
	return Vector3((i - mid) * spacing, t * t * SAG * spread, deg_to_rad(t * MAX_ANGLE_DEG * spread))

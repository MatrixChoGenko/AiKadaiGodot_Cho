class_name BattleAmbience extends Control
## ⑤ Presentation：戦闘背景の上に重ねる環境のエフェクト（光の筋＋塵、地面の霧、ホタル）。値は BackdropData の
## Light / Mist / Fireflies。どれも全画面の ColorRect のシェーダーで、使わないものは非表示にして描画しない。
## 重なり順：背景 → この Control（霧 → 光の筋 → 奥のホタル）→ Field（キャラ）→ front（手前のホタル）→ UI。

## 手前のホタル（Field より後ろに置いた ColorRect）。
@export var front: ColorRect

@onready var _mist: ColorRect = $Mist
@onready var _rays: ColorRect = $Rays
@onready var _fireflies: ColorRect = $Fireflies


func apply(b: BackdropData) -> void:
	_rays.visible = b != null and b.rays_enabled
	_mist.visible = b != null and b.mist_amount > 0.0
	_fireflies.visible = b != null and b.fireflies_back > 0.0
	if front != null:
		front.visible = b != null and b.fireflies_front > 0.0
	if b == null:
		return
	var rays := _rays.material as ShaderMaterial
	rays.set_shader_parameter(&"origin", b.ray_origin)
	rays.set_shader_parameter(&"angle_deg", b.ray_angle)
	rays.set_shader_parameter(&"spread_deg", b.ray_spread)
	rays.set_shader_parameter(&"ray_color", b.ray_color)
	rays.set_shader_parameter(&"intensity", b.ray_intensity)
	rays.set_shader_parameter(&"ray_length", b.ray_length)
	rays.set_shader_parameter(&"streaks", b.ray_streaks)
	rays.set_shader_parameter(&"dust_amount", b.dust_amount)
	rays.set_shader_parameter(&"dust_brightness", b.dust_brightness)
	var mist := _mist.material as ShaderMaterial
	mist.set_shader_parameter(&"amount", b.mist_amount)
	mist.set_shader_parameter(&"mist_color", b.mist_color)
	mist.set_shader_parameter(&"top", b.mist_top)
	mist.set_shader_parameter(&"bottom", b.mist_bottom)
	for pair: Array in [[_fireflies, b.fireflies_back], [front, b.fireflies_front]]:
		var rect := pair[0] as ColorRect
		if rect == null:
			continue
		var mat := rect.material as ShaderMaterial
		mat.set_shader_parameter(&"density", pair[1])
		mat.set_shader_parameter(&"color", b.firefly_color)

// 休憩所の焚き火の周りの光。楕円の柔らかい光を加算で重ね、明るさをゆらゆら明滅させる（炎の揺れに合わせた不規則な周期）。
shader_type canvas_item;
render_mode blend_add;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float intensity = 0.32;
// 明滅の幅（0 = 一定）と速さ
uniform float flicker = 0.35;
uniform float speed = 3.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float glow = pow(max(0.0, 1.0 - r), 2.2);
	float f = 1.0 - flicker * vnoise(vec2(TIME * speed, 0.0)) - flicker * 0.4 * vnoise(vec2(TIME * speed * 2.7, 5.0));
	COLOR = vec4(glow_color.rgb, clamp(glow * intensity * f, 0.0, 1.0) * COLOR.a);
}

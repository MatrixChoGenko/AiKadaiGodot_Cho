// 戦闘背景の地面の霧。全画面の ColorRect に描き、top〜bottom の帯（画面 UV の y）にだけ薄い霧をゆっくり横へ流す。
// 速さの違う 2 層の fbm を重ね、横に伸ばして「たなびく」形にする。
shader_type canvas_item;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 mist_color : source_color = vec4(0.45, 0.66, 0.6, 1.0);
uniform float amount = 0.25;   // 最も濃い所の不透明度（0 = なし）
uniform float top = 0.45;      // 霧の帯の上端（画面 UV）
uniform float bottom = 0.95;   // 霧の帯の下端
uniform float speed = 0.02;    // 流れる速さ（画面の高さ / 秒）

void fragment() {
	float t = TIME;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 q = vec2(UV.x * aspect, UV.y);
	float n1 = fbm(q * vec2(1.6, 5.0) + vec2(t * speed, 0.0));
	float n2 = fbm(q * vec2(3.2, 9.0) + vec2(-t * speed * 1.7, t * 0.004) + n1);
	float m = smoothstep(0.38, 0.78, n1 * 0.6 + n2 * 0.5);
	float band = smoothstep(top, top + 0.15, UV.y) * smoothstep(bottom, bottom - 0.25, UV.y);
	COLOR = vec4(mist_color.rgb, m * band * amount);
}

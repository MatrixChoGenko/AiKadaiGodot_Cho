// 休憩所の焚き火の揺らぐ炎。背景の絵に描かれた炎の上に加算で重ね、動いているように見せる。
// ColorRect に貼る：UV の下辺中央 = 炎の根元、上辺 = 炎の先。
// 形は「下が太く上が細い涙形」を fbm のノイズで横に揺らし、上へ流れるノイズで先端を千切る。色は芯（白っぽい黄）→ 橙 → 赤。
shader_type canvas_item;
render_mode blend_add;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.6, 0.18, 1.0);
uniform vec4 edge_color : source_color = vec4(0.9, 0.22, 0.08, 1.0);
uniform float intensity = 0.7;
// 炎が上へ流れる速さ（UV / 秒）と、揺れの大きさ
uniform float speed = 1.6;
uniform float sway = 0.32;

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);   // x: -1〜1、y: 0（根元）〜 1（先）
	float t = TIME * speed;
	float n = fbm(vec2(p.x * 2.5, p.y * 3.0 - t));
	float n2 = fbm(vec2(p.x * 5.0 + 3.1, p.y * 6.0 - t * 1.7));
	float width = pow(max(0.0, 1.0 - p.y), 0.75) * 0.62 + 0.04;
	float x = p.x + (n - 0.5) * sway * p.y;
	float d = abs(x) / width;
	float flame = 1.0 - smoothstep(0.55, 1.0, d + (n2 - 0.5) * 0.6 * p.y + p.y * 0.18);
	flame *= smoothstep(0.0, 0.08, p.y + 0.02);   // 根元は少しぼかす
	float heat = clamp(flame * (1.15 - p.y), 0.0, 1.0);
	vec3 col = mix(edge_color.rgb, mid_color.rgb, smoothstep(0.15, 0.55, heat));
	col = mix(col, core_color.rgb, smoothstep(0.6, 0.95, heat));
	COLOR = vec4(col, clamp(flame * intensity, 0.0, 1.0) * COLOR.a);
}

// カードの 3 択で、レアのカードの後ろでゆっくり回る放射光（StS2 の「Choose a Card」の金色の光）。
// カードより大きい正方形の ColorRect に貼る（中心 = カードの中心）。加算。
// 筋は本数の違う 3 つの正弦の山を重ねて不規則にし、それぞれ別の速さで回す。中心の柔らかい光は core。
shader_type canvas_item;
render_mode blend_add;

uniform vec4 ray_color : source_color = vec4(1.0, 0.78, 0.3, 1.0);
uniform float intensity = 0.85;
// 回る速さ（rad / 秒）
uniform float speed = 0.18;
uniform float core = 0.35;
// カードごとに筋の位相をずらす
uniform float seed = 0.0;

float lobe(float a, float n, float phase, float sharp) {
	return pow(max(0.0, sin(a * n + phase)), sharp);
}

void fragment() {
	float m = COLOR.a;
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	float t = TIME * speed;
	float v = lobe(a - t, 7.0, seed, 3.0) * 0.55
			+ lobe(a + t * 0.6, 11.0, seed * 2.3 + 1.0, 5.0) * 0.45
			+ lobe(a - t * 1.7, 5.0, seed * 0.7 + 2.0, 2.0) * 0.25;
	float fall = 1.0 - smoothstep(0.25, 1.0, r);
	float glow = (1.0 - smoothstep(0.0, 0.75, r)) * core;
	float alpha = clamp((v * fall + glow) * intensity, 0.0, 1.0) * m;
	COLOR = vec4(ray_color.rgb, alpha);
}

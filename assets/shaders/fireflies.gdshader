// 戦闘背景のホタル。全画面の ColorRect に描く。画面をセルに分け、セルごとに 1 匹（density の割合）が
// セルの中をゆっくりさまよい、個体ごとの周期で点いたり消えたりする。格子全体も drift でゆっくり流れる。
// 奥の層（キャラの後ろ）と手前の層（キャラの前・少数・大きくぼやけた）で同じシェーダーを値を変えて使う。
shader_type canvas_item;
render_mode blend_add;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 color : source_color = vec4(0.78, 1.0, 0.42, 1.0);
uniform float brightness = 1.0;
uniform float density = 0.35;      // ホタルのいるセルの割合（0 = なし）
uniform float cell_px = 150.0;     // セルの大きさ（画面の高さ 1080 に対する px）
uniform float core_px = 2.2;       // 芯の半径
uniform float halo_px = 12.0;      // 光の輪の半径（cell_px の半分より小さく）
uniform float halo_amount = 0.35;
uniform vec2 drift = vec2(6.0, -4.0); // 格子が流れる速さ（px / 秒）
uniform float y_top = 0.08;        // 出る範囲（画面 UV の y）
uniform float y_bottom = 0.75;
uniform float seed = 0.0;          // 層ごとに変えて配置をずらす

void fragment() {
	float t = TIME;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = UV * vec2(aspect, 1.0) * 1080.0 - drift * t;
	vec2 base = floor(p / cell_px);
	float s = 0.0;
	// 光の輪が隣のセルへはみ出すので 3x3 を見る
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float h = hash12(cell + seed * 13.1);
			if (h > density) {
				continue;
			}
			float h2 = hash12(cell + 5.3 + seed);
			float h3 = hash12(cell + 9.7 + seed);
			// セルの中を 2 つの周期の組み合わせでさまよう（8 の字のような不規則な軌道）
			vec2 wander = vec2(sin(t * (0.21 + h2 * 0.25) + h * 40.0) + 0.5 * sin(t * (0.53 + h3 * 0.3) + h2 * 20.0),
					cos(t * (0.17 + h3 * 0.22) + h2 * 30.0) + 0.5 * sin(t * (0.47 + h * 0.3) + h3 * 10.0));
			vec2 c = (cell + 0.5 + wander * 0.2) * cell_px;
			float d = length(p - c);
			// 点滅：sin を持ち上げて切るので、点いている時間と消えている時間がある
			float blink = smoothstep(-0.3, 0.7, sin(t * (0.5 + h2 * 0.9) + h3 * 60.0));
			float glow = exp(-d * d / (core_px * core_px)) + halo_amount * exp(-d * d / (halo_px * halo_px));
			s += glow * blink * (0.6 + 0.4 * h3);
		}
	}
	float band = smoothstep(y_top, y_top + 0.08, UV.y) * smoothstep(y_bottom, y_bottom - 0.12, UV.y);
	COLOR = vec4(color.rgb, clamp(s * band * brightness, 0.0, 1.0));
}

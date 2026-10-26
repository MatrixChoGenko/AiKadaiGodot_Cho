// 戦闘背景のボリュームライト（god rays）＋光の塵。全画面の ColorRect に描き、背景の上・キャラの下に置く。
// 光の筋：origin から angle_deg 方向へ、半角 spread_deg で放射。角度方向にノイズで筋を切り出し、ゆっくり流して明滅させる。
// 光の塵：細かい粒がゆっくり漂い、光の筋に入ったものだけが明るく見える（チンダル現象）。
shader_type canvas_item;
render_mode blend_add;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec2 origin = vec2(0.2, -0.15);     // 光源の位置（画面 UV。画面外でもよい）
uniform float angle_deg = 70.0;             // 筋の中心の向き（0 = 右、90 = 下）
uniform float spread_deg = 18.0;            // 扇の半角
uniform vec4 ray_color : source_color = vec4(0.62, 0.95, 0.82, 1.0);
uniform float intensity = 0.2;
uniform float ray_length = 1.3;             // 減衰距離（画面の高さ = 1）
uniform float streaks = 1.0;                // 筋の密度
uniform float dust_amount = 0.45;           // 塵の密度 0〜1（0 = なし）
uniform float dust_brightness = 1.0;

// intensity を掛ける前の筋の強さ（0〜1）。塵が筋の中にいるかの判定にも使う。
float beams(vec2 uv, float t, float aspect) {
	vec2 d = (uv - origin) * vec2(aspect, 1.0);
	float dist = length(d);
	float a = atan(d.y, d.x);
	float da = abs(atan(sin(a - radians(angle_deg)), cos(a - radians(angle_deg))));  // -π〜π に折り返した角度差
	float spread = radians(spread_deg);
	float cone = smoothstep(spread, spread * 0.35, da);
	// 2 層のノイズを角度方向に取り、ゆっくり流す → 太さの違う筋が少しずつ入れ替わる
	float s1 = fbm(vec2(a * 22.0 * streaks, t * 0.06));
	float s2 = vnoise(vec2(a * 60.0 * streaks + 3.0, t * 0.15));
	float streak = smoothstep(0.32, 0.72, s1) * (0.6 + 0.4 * s2);
	float breathe = 0.7 + 0.3 * sin(t * 0.5 + a * 9.0);
	float fall = exp(-dist / ray_length) * smoothstep(0.0, 0.1, dist);
	return cone * (0.25 + 0.75 * streak) * breathe * fall;
}

float dust(vec2 uv, float t, vec2 res) {
	float aspect = res.x / res.y;
	float s = 0.0;
	for (int l = 0; l < 3; l++) {
		float fl = float(l);
		float scale = 12.0 + fl * 8.0;  // 画面の高さあたりのセル数。奥の層ほど小さく多い
		vec2 drift = vec2(0.010 + fl * 0.006, -0.012 - fl * 0.006) * t;
		vec2 p = (uv * vec2(aspect, 1.0) + drift) * scale;
		vec2 cell = floor(p);
		vec2 f = fract(p);
		float h = hash12(cell + fl * 17.0);
		if (h > dust_amount) {
			continue;
		}
		vec2 c = 0.2 + 0.6 * vec2(hash12(cell + 3.1 + fl), hash12(cell + 7.7 + fl));
		c += 0.08 * vec2(sin(t * 0.7 + h * 30.0), cos(t * 0.5 + h * 20.0));
		float r_px = 0.5 + fl * 0.35 + h * 0.9;
		float d_px = length((f - c) / scale) * res.y;
		float twinkle = 0.55 + 0.45 * sin(t * (1.2 + h * 2.5) + h * 40.0);
		s += smoothstep(r_px + 1.0, 0.0, d_px) * twinkle * (0.6 + 0.2 * fl);
	}
	return s;
}

void fragment() {
	float t = TIME;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float b = beams(UV, t, res.x / res.y);
	float motes = 0.0;
	if (dust_amount > 0.0) {
		motes = dust(UV, t, res) * dust_brightness * (0.04 + 1.3 * b);  // 筋の外はごく薄く、筋の中で明るく
	}
	COLOR = vec4(ray_color.rgb, clamp(b * intensity + motes, 0.0, 1.0));
}

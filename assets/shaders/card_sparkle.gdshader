// カードのフレームの金属に、ランダムな位置で四芒星のきらめきがときどき光る（銀・金のカード）。
// TEXTURE はフレーム画像で、アルファをマスクにする（カードの外には出さない）。フレームより手前・文字より奥に置く。
// 出る場所：外周の金属の帯・絵の窓の縁・コインの輪 3 つ（コスト、下の左右）・爪・王冠（has_crown のとき）。
// きらめきは sparkle_count 個の枠ごとに周期 period を持ち、周期の最初の LIFE の間だけ光る。周期ごとに場所を選び直す。
// 位置は card_size のピクセル座標。フレーム（1024x1440）を測った値なので、フレームを作り直したら測り直す。
shader_type canvas_item;
render_mode blend_add;

#include "res://assets/shaders/noise.gdshaderinc"

const float LIFE = 0.28;

uniform int sparkle_count = 0;  // 0〜4
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float brightness = 1.6;
uniform float size_px = 11.0;   // 光芒の長さ（px）。光っている間に size_px + grow_px まで伸びる
uniform float grow_px = 14.0;
uniform vec2 card_size = vec2(300.0, 420.0);
uniform vec4 rim_rect = vec4(0.072, 0.065, 0.928, 0.931);     // 外周の金属の帯の中心線（UV）
uniform vec4 window_rect = vec4(0.19, 0.126, 0.812, 0.4925);   // 絵の窓の縁（UV）
uniform vec3 ring_cost = vec3(0.166, 0.132, 31.0);            // コインの輪：中心（UV）と半径（px）
uniform vec3 ring_left = vec3(0.166, 0.864, 26.0);
uniform vec3 ring_right = vec3(0.834, 0.864, 26.0);
uniform vec2 claw = vec2(0.87, 0.11);
uniform vec2 crown = vec2(0.5, 0.06);
uniform bool has_crown = false;
uniform float point_jitter_px = 14.0;
uniform float seed = 0.0;       // カードごとに変える（同じレアリティのカードが同時に同じ所で光らないように）

// 矩形の周上の点（t ∈ [0, 1)、px）。
vec2 rect_point(vec4 r, float t) {
	vec2 lo = r.xy * card_size;
	vec2 hi = r.zw * card_size;
	vec2 sz = hi - lo;
	float l = t * 2.0 * (sz.x + sz.y);
	if (l < sz.x) return lo + vec2(l, 0.0);
	l -= sz.x;
	if (l < sz.y) return vec2(hi.x, lo.y + l);
	l -= sz.y;
	if (l < sz.x) return vec2(hi.x - l, hi.y);
	l -= sz.x;
	return vec2(lo.x, hi.y - l);
}

vec2 ring_point(vec3 ring, float t) {
	return ring.xy * card_size + ring.z * vec2(cos(t * TAU), sin(t * TAU));
}

// 枠 fi の周期 k のきらめきの位置（px）。外周 45%、窓の縁 15%、コインの輪 25%、爪・王冠 15%。
vec2 spot(float fi, float k) {
	float r = hash12(vec2(k + 0.5, fi * 3.1));
	float h = hash12(vec2(fi * 7.0, k));
	if (r < 0.45) return rect_point(rim_rect, h);
	if (r < 0.6) return rect_point(window_rect, h);
	if (r < 0.85) {
		float which = floor(h * 3.0);
		vec3 ring = which < 1.0 ? ring_cost : (which < 2.0 ? ring_left : ring_right);
		return ring_point(ring, fract(h * 3.0));
	}
	vec2 c = has_crown && h < 0.6 ? crown : claw;
	vec2 j = (vec2(hash12(vec2(k, fi + 9.0)), hash12(vec2(fi + 4.0, k))) - 0.5) * 2.0 * point_jitter_px;
	return c * card_size + j;
}

// 四芒星：d は星の中心からの位置（px）、size は光芒の長さ（px）。
float star4(vec2 d, float size) {
	float r = length(d);
	float core = exp(-r * r / (size * size * 0.06));
	float halo = exp(-r / (size * 0.3)) * 0.35;
	float rx = pow(max(0.0, 1.0 - abs(d.x) / size), 1.5) * exp(-abs(d.y) * 0.6) * 1.2;
	float ry = pow(max(0.0, 1.0 - abs(d.y) / size), 1.5) * exp(-abs(d.x) * 0.6) * 1.2;
	return clamp(core + halo + rx + ry, 0.0, 1.0);
}

void fragment() {
	float t = TIME;
	vec2 p = UV * card_size;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= sparkle_count) {
			break;
		}
		float fi = float(i) + seed * 5.0;
		float period = 1.8 + hash12(vec2(fi, 1.0)) * 1.4;
		float tt = t / period + hash12(vec2(fi, 2.0));
		float f = fract(tt);
		if (f < LIFE) {
			float k = floor(tt);
			float amp = sin(f / LIFE * PI);
			vec2 d = p - spot(fi, k);
			if (hash12(vec2(k, fi)) > 0.5) {  // 半分は 45° 回して単調さを避ける
				d = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * d;
			}
			s = max(s, star4(d, size_px + grow_px * amp) * amp);
		}
	}
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(mix(sparkle_color.rgb, vec3(1.0), 0.5), clamp(s * a * brightness, 0.0, 1.0));
}

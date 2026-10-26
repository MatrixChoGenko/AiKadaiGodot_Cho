// タイトル画面の背景の空をゆっくり動かす。背景の TextureRect に貼る（TEXTURE = 背景の絵）。
// 空（UV の y が sky_bottom より上）だけを、流れる fbm のノイズで少しゆがめ（雲がうねる）、明るさをゆらす（雲の切れ間の光が流れる）。
// 地上（森・崖・人物）は動かさない。
shader_type canvas_item;

#include "res://assets/shaders/noise.gdshaderinc"

uniform float sky_bottom = 0.5;   // ここより下は動かさない（UV の y）
uniform float fade = 0.18;        // 境目をぼかす幅
uniform float warp = 0.006;       // ゆがみの大きさ（UV）
uniform float speed = 0.018;      // ノイズが流れる速さ（UV / 秒）
uniform float light = 0.07;       // 明るさのゆれの幅

// fragment() の COLOR は既にテクスチャの色を掛けた値なので、頂点の色（modulate）だけを別に持っておく。
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float sky = 1.0 - smoothstep(sky_bottom - fade, sky_bottom, uv.y);
	vec2 q = uv * vec2(3.0, 2.0);
	float t = TIME * speed;
	vec2 w = vec2(fbm(q + vec2(t, 0.0)), fbm(q * 1.7 + vec2(-t * 0.7, 3.1))) - 0.5;
	uv += sky * warp * 2.0 * w;
	vec4 c = texture(TEXTURE, uv);
	float l = fbm(uv * vec2(2.0, 1.5) + vec2(t * 1.5, 7.3)) - 0.5;
	c.rgb *= 1.0 + sky * light * 2.0 * l;
	COLOR = c * tint;
}

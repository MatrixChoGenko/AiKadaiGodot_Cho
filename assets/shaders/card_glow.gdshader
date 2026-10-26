// カードの輪郭グロー。フレーム画像の不透明な輪郭を外側へぼかして広げるので、王冠など枠からはみ出した飾りも光で包む。
// ノードはカードより四辺 margin px 大きい。frame_tex はカードのピクセル座標でサンプリングする
// （TEXTURE だとノード全体に引き伸ばされるので uniform で渡す）。
shader_type canvas_item;
render_mode blend_add;

uniform sampler2D frame_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 glow_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float radius = 18.0;   // 広がる半径（px）。margin より小さくする
uniform float margin = 24.0;   // ノードがカードからはみ出す量（px）。card_view.tscn の Glow の offset と一致させる
uniform vec2 card_size = vec2(300.0, 420.0);
uniform float pulse_speed = 2.4;
uniform float pulse_amount = 0.25; // 0 で明滅なし

float frame_a(vec2 p) {
	vec2 uv = p / card_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(frame_tex, uv).a;
}

void fragment() {
	// ノードの UV → カードのピクセル座標（カードの左上が原点。外側は負か card_size より大きい）
	vec2 p = UV * (card_size + vec2(margin * 2.0)) - vec2(margin);
	float sum = 0.0;
	float wsum = 0.0;
	// 3 つの半径 × 12 方向のリングでアルファを平均する（簡易的な膨張 + ぼかし）
	for (int r = 1; r <= 3; r++) {
		float rr = radius * float(r) / 3.0;
		float w = 1.0 - float(r - 1) * 0.25;  // 外側のリングほど軽く
		for (int i = 0; i < 12; i++) {
			float ang = TAU * float(i) / 12.0 + float(r) * 0.26;  // リングごとに角度をずらしてムラを減らす
			sum += frame_a(p + vec2(cos(ang), sin(ang)) * rr) * w;
			wsum += w;
		}
	}
	float g = clamp(sum / wsum * 1.8, 0.0, 1.0);
	g *= 1.0 - frame_a(p);  // カードの外側だけ残す（透明な絵の窓の中は光らせない）
	float pulse = 1.0 - pulse_amount + pulse_amount * sin(TIME * pulse_speed);
	COLOR = vec4(glow_color.rgb, g * intensity * pulse * glow_color.a);
}

// カードのスイープ光：45° の白い光の帯が左上から右下へ 1 回流れる。
// TEXTURE はフレーム画像で、アルファだけを「光ってよい範囲」に使う（カードの外の透明な所は光らない）。
// フレームの絵の窓は透明なので art_rect で補う。
shader_type canvas_item;
render_mode blend_add;

uniform float progress = -1.0; // 0 → 1 で 1 回流れる。0 未満なら何も描かない
uniform float width = 0.09;    // 帯の幅（対角の座標 0〜1 に対する割合）
uniform float strength = 0.6;
uniform vec2 card_size = vec2(300.0, 420.0);
uniform vec4 art_rect = vec4(0.202148, 0.139583, 0.799805, 0.483333); // 絵の窓の UV（左, 上, 右, 下）。card_view.tscn の ArtBox と同じ

void fragment() {
	float a = texture(TEXTURE, UV).a;
	if (UV.x >= art_rect.x && UV.x <= art_rect.z && UV.y >= art_rect.y && UV.y <= art_rect.w) {
		a = 1.0;
	}
	// 対角の座標（0 = 左上、1 = 右下）。ピクセルの比率で求めるので縦長のカードでも帯が 45° になる
	vec2 p = UV * card_size;
	float d = (p.x + p.y) / (card_size.x + card_size.y);
	float pos = mix(-width, 1.0 + width, progress);
	float band = 1.0 - smoothstep(0.0, width, abs(d - pos));
	band *= band;
	COLOR = vec4(1.0, 1.0, 1.0, band * strength * a * step(0.0, progress));
}

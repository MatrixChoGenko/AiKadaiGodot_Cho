shader_type canvas_item;
// 背景の絵をぼかして暗くする（図鑑の背景。タイトルの絵を使い回す）。7×7 の箱型ぼかし。
// COLOR はテクスチャの色が掛かった値なので使わず、自分で読んだ色だけで決める。

uniform float radius = 5.0;      // 1 タップの間隔（テクスチャの px）
uniform float brightness = 0.32;
uniform vec3 tint = vec3(0.85, 0.9, 1.0);

void fragment() {
	vec3 sum = vec3(0.0);
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * radius).rgb;
		}
	}
	COLOR = vec4(sum / 49.0 * brightness * tint, 1.0);
}

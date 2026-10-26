// 照準の輪郭線（inverted hull）。裏面を画面の面内で法線方向に広げ、さらにカメラから遠ざけて描く。
// 遠ざけることで、腕や顔など別パーツの殻が体の手前に出ず、外周（シルエット）だけが見える。
// 太さはビュー空間（= ワールド単位）なので、モデルの拡大率に左右されない。
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float width = 0.05;
uniform float push_back = 0.6;

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float len = length(n.xy);
	if (len > 0.0001) {
		v.xy += n.xy / len * width;
	}
	v.z -= push_back;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}

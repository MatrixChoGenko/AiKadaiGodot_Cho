class_name BackdropData extends Resource
## ② Content：戦闘背景（GameDesign §15.4）。素材がない間は base_color だけで描く。
## Light / Mist / Fireflies は背景の上に重ねる環境のエフェクト（BattleAmbience）。位置は画面 UV（0〜1、画面外でもよい）。

@export var id: StringName
@export var texture: Texture2D
@export var tint: Color = Color.WHITE
@export var base_color: Color = Color(0.07, 0.07, 0.1)
@export_range(0.0, 1.0) var darken: float = 0.35
@export_range(0.0, 1.0) var vignette: float = 0.5
## 背景画像をトリミングするときの縦の基準位置（0 = 上、1 = 下）。
@export_range(0.0, 1.0) var anchor_y: float = 0.5

@export_group("Light")
## ボリュームライト（光の筋）＋光の塵（assets/shaders/god_rays.gdshader）。
@export var rays_enabled: bool = false
@export var ray_origin: Vector2 = Vector2(0.2, -0.15)
## 光の筋の中心の向き（度）：0 = 右、90 = 下。
@export_range(-180.0, 180.0) var ray_angle: float = 70.0
## 扇の半角（度）。
@export_range(1.0, 90.0) var ray_spread: float = 18.0
@export var ray_color: Color = Color(0.62, 0.95, 0.82)
@export_range(0.0, 1.0) var ray_intensity: float = 0.2
## 減衰距離（画面の高さ = 1）。
@export_range(0.1, 3.0) var ray_length: float = 1.3
## 筋の密度。
@export_range(0.2, 3.0) var ray_streaks: float = 1.0
## 塵の密度（0 = なし）。
@export_range(0.0, 1.0) var dust_amount: float = 0.45
@export_range(0.0, 3.0) var dust_brightness: float = 1.0

@export_group("Mist")
## 地面の霧の最も濃い所の不透明度（0 = なし。assets/shaders/ground_mist.gdshader）。
@export_range(0.0, 1.0) var mist_amount: float = 0.0
@export var mist_color: Color = Color(0.45, 0.66, 0.6)
## 霧の帯の上端・下端（画面 UV の y）。
@export_range(0.0, 1.0) var mist_top: float = 0.45
@export_range(0.0, 1.0) var mist_bottom: float = 0.95

@export_group("Fireflies")
## ホタルのいるセルの割合（0 = なし。assets/shaders/fireflies.gdshader）。奥 = キャラの後ろ、手前 = キャラの前（少数・大きくぼやけた）。
@export_range(0.0, 1.0) var fireflies_back: float = 0.0
@export_range(0.0, 1.0) var fireflies_front: float = 0.0
@export var firefly_color: Color = Color(0.78, 1.0, 0.42)

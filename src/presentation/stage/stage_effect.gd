class_name StageEffect extends Node3D
## ⑤ Presentation：舞台の 3D エフェクト 1 回分（scenes/fx/stage/*.tscn の根）。BattleStage.spawn_fx が作る。
## 子の GPUParticles3D（one_shot・emitting = false で作っておく）を一斉に出し、いちばん長い寿命が過ぎたら自分を消す。
## 見た目の調整はシーンを開いて Inspector で行う（エディタでは各 GPUParticles3D の Emitting を押すと試し撃ちできる）。
## 舞台のカメラは真横の正投影なので、テクスチャはカメラを向く板（ビルボード）で描く。
## 舞台の SubViewport は背景が透明なので、材質は加算（Add）ではなく通常の混合（Mix）にする（加算は透明な所に出ない）。

## 再生の速さ（Presenter の倍率）。パーティクルと寿命の計時に掛ける。
var speed: float = 1.0
## 付いていくアクター（BattleStage.spawn_on）。毎フレーム anchor.position + anchor_offset に合わせる。null なら動かない。
var anchor: Node3D
var anchor_offset: Vector3 = Vector3.ZERO

var _left: float = 0.0


## at に出す。facing = +1 / -1（-1 なら左右を反転。「相手から遠ざかる向き」に飛ばすのに使う）。size は全体の拡大率。
func play(at: Vector3, facing: float = 1.0, size: float = 1.0) -> void:
	position = at
	rotation.y = 0.0 if facing >= 0.0 else PI
	scale = Vector3.ONE * size
	_left = 0.0
	for p in particles():
		p.speed_scale = speed
		p.restart()
		_left = maxf(_left, p.lifetime)


func particles() -> Array[GPUParticles3D]:
	var list: Array[GPUParticles3D] = []
	for c in get_children():
		if c is GPUParticles3D:
			list.append(c)
	return list


func is_playing() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	if anchor != null and is_instance_valid(anchor):
		position = anchor.position + anchor_offset
	_left -= delta * speed
	if _left <= 0.0:
		queue_free()

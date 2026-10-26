class_name FxNode extends Control
## ⑤ Presentation：Fx のプールで使い回すエフェクトの基底クラス。再生が終わったら finished を出す（Fx がプールに戻す）。

signal finished

var kind: StringName
var _tween: Tween


## global_pos を中心に再生する。
func play(_global_pos: Vector2, _args: Dictionary) -> void:
	pass


func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	finished.emit()


func _new_tween() -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	return _tween

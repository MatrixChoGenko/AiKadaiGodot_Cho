extends SceneTree
## カードの輪郭グローとスイープ光を撮る（skill trycard-dev）。見た目の調整用。
## 使い方：Godot --path <project> -s <this file> -- <出力先フォルダ> [scale]
## 本体（capture_card_fx_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_card_fx_impl.gd").new()
	impl.call("start", self)

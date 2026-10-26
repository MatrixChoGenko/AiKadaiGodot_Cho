extends SceneTree
## TryCard の画面を描画ありで起動してスクリーンショットを撮る（skill trycard-dev）。
## 使い方：Godot --path <project> -s <this file> -- <出力先フォルダ>
## 本体（capture_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_impl.gd").new()
	impl.call("start", self)

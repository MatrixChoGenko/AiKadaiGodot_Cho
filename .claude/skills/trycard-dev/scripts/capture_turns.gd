extends SceneTree
## TryCard のターンの切り替え（バナー・ドロー・ターン終了ボタン・手札の捨て札）を毎フレーム撮る（skill trycard-dev）。
## 使い方：Godot --path <project> --fixed-fps 30 -s <this file> -- <出力先フォルダ> [encounter id]
## 本体（capture_turns_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_turns_impl.gd").new()
	impl.call("start", self)

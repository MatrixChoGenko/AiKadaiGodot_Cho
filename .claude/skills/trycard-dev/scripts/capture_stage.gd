extends SceneTree
## TryCard の 3D 舞台（戦闘の動き）を連続で撮る（skill trycard-dev）。
## 使い方：Godot --path <project> -s <this file> -- <出力先フォルダ>
## 本体（capture_stage_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_stage_impl.gd").new()
	impl.call("start", self)

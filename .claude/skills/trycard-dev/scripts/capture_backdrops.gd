extends SceneTree
## 戦闘背景と環境のエフェクト（光の筋・霧・ホタル。BattleAmbience）を、背景ごとに撮る（skill trycard-dev）。
## 使い方：Godot --path <project> --fixed-fps 60 -s <this file> -- <出力先フォルダ>
## 本体（capture_backdrops_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_backdrops_impl.gd").new()
	impl.call("start", self)

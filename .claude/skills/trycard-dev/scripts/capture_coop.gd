extends SceneTree
## 協力プレイの画面を描画ありで撮る（skill trycard-dev）：ロビー（ホスト・4 人）と、4 人の戦闘画面（味方の並び）。
## 使い方：Godot --path <project> -s <this file> -- <出力先フォルダ>
## 本体（capture_coop_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_coop_impl.gd").new()
	impl.call("start", self)

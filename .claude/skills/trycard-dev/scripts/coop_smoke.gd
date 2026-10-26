extends SceneTree
## 協力プレイのスモークテスト（skill trycard-dev）：本物の Main を 2 つのプロセスで起動し、ホスト / 参加者として
## UiBot が 1 ランを最後まで遊ぶ。ENet は localhost。結果は "COOP_SMOKE {...}" の 1 行で出す。
## 使い方（2 つ同時に起動する。coop_smoke.ps1 がまとめて行う）：
##   Godot --headless --path <project> -s <this file> -- host <port> <seed>
##   Godot --headless --path <project> -s <this file> -- client <port> <seed>
## 本体（coop_smoke_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/coop_smoke_impl.gd").new()
	impl.call("start", self)

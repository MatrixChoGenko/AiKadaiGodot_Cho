extends SceneTree
## 全カードの面（基本と強化後）を一覧で撮る（skill trycard-dev）。フレーム・説明の字の大きさの確認用。
## 使い方：Godot --path <project> -s <this file> -- <出力先フォルダ> [scale]
## 本体（capture_cards_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_cards_impl.gd").new()
	impl.call("start", self)

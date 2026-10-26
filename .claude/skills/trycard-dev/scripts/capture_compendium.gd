extends SceneTree
## 図鑑（CompendiumScreen）を撮る（skill trycard-dev）。メニュー → カード一覧 → ホバー → 絞り込み + 強化版 → カードの拡大 → レリック → レリックの拡大 → ポーション。
## 使い方：Godot --path <project> -s <this file> -- <出力先フォルダ>
## 本体（capture_compendium_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_compendium_impl.gd").new()
	impl.call("start", self)

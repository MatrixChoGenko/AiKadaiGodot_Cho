extends SceneTree
## TryCard の舞台エフェクト（scenes/fx/stage/*.tscn）を、ゲームを通さずに並べて連続で撮る（skill trycard-dev）。
## 使い方：Godot --path <project> --fixed-fps 60 -s <this file> -- <出力先フォルダ> [エフェクト名...]（省略時は BattleStage.EFFECTS の全部）
## Fx.SCENES の名前（card_burst / victory など 2D のエフェクト）も指定できる。
## 本体（capture_fx_impl.gd）は Autoload の登録後に load() する。

var impl: RefCounted


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	impl = load((get_script() as Script).resource_path.get_base_dir() + "/capture_fx_impl.gd").new()
	impl.call("start", self)

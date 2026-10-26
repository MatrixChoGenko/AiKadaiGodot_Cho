@abstract class_name NodeHandler extends RefCounted
## ④ Flow：マップノードの種類ごとの Strategy（Architecture §10.2）。RunController がノードの種類で表を引いて呼ぶ。
## enter() はノードの内容（ショップの在庫、イベント、戦闘）を作るだけで、フェーズの通知とチェックポイントは RunController が行う。


## このノードに入ったときのフェーズ。
@abstract func phase() -> RunPhase.Id


## 内容を生成する。node_entered のチェックポイントの後に呼ばれる（戦闘系はチェックポイントを自分で出す）。
@abstract func enter(run: RunController, node: MapNode) -> void


## ロード時の再開。既定では enter() をやり直す（同じ乱数状態から始まるので同じ内容になる）。
func on_resume(run: RunController, node: MapNode) -> void:
	enter(run, node)

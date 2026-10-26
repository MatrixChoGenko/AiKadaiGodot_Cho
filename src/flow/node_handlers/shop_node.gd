class_name ShopNode extends NodeHandler
## ④ Flow：ショップ。入ったときに在庫を 1 回だけ生成する（GameDesign §12.3）。


func phase() -> RunPhase.Id:
	return RunPhase.Id.SHOP


func enter(run: RunController, _node: MapNode) -> void:
	# 協力プレイでは品揃えも各自（GameDesign §21）。席の順に作るので、どの PC でも同じ在庫になる。
	for p in run.state.players:
		p.shop = ShopFactory.create(run.loot(), p.owned_relics())

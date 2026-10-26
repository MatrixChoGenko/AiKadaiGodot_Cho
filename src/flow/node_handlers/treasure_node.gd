class_name TreasureNode extends NodeHandler
## ④ Flow：宝箱（GameDesign §12.2）。レリック 1 つ + ゴールド。受け取りは報酬と同じ take_reward()。


func phase() -> RunPhase.Id:
	return RunPhase.Id.TREASURE


func enter(run: RunController, _node: MapNode) -> void:
	for p in run.state.players:
		p.pending_reward = RewardFactory.for_treasure(run.loot(), p.owned_relics())

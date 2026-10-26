class_name RestNode extends NodeHandler
## ④ Flow：休憩所（GameDesign §12.5）。「休む」と「鍛える」のどちらか 1 つを選ぶ（付録 C の C32）。


func phase() -> RunPhase.Id:
	return RunPhase.Id.REST


func enter(run: RunController, _node: MapNode) -> void:
	for p in run.state.players:
		p.rest_used = false

class_name EventNode extends NodeHandler
## ④ Flow：ランダムイベント（GameDesign §12.4）。イベントはマップ生成時に割り当て済み。


func phase() -> RunPhase.Id:
	return RunPhase.Id.EVENT


func enter(run: RunController, node: MapNode) -> void:
	run.state.event = run.content.event(node.event)
	for p in run.state.players:
		p.event_choice = -1
	if run.state.event == null:
		push_error("EventNode: unknown event %s" % node.event)
		for p in run.state.players:
			p.event_choice = 0   # 詰まらないよう、離れられるようにする

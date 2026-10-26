@abstract class_name CombatNode extends NodeHandler
## ④ Flow：戦闘系ノード（通常 / エリート / ボス）の共通部分。エンカウントはマップ生成時に割り当て済み。
## ロード時の再開は RunState.active_encounter から RunController が行うので on_resume は使わない。


func phase() -> RunPhase.Id:
	return RunPhase.Id.COMBAT


func enter(run: RunController, node: MapNode) -> void:
	run.start_combat(run.content.encounter(node.encounter), true)

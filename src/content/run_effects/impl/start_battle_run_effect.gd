class_name StartBattleRunEffect extends RunEffect
## 戦闘を予約する（RunState.queued_encounter に書くだけ。開戦は RunController.leave_node が行う）。

## null = 現在のアクトのランダムな通常戦闘（序盤の行なら序盤用から）。
@export var encounter: EncounterData
## 勝利時に通常の戦闘報酬を出すか。
@export var rewards: bool = true


func apply(ctx: RunEffectContext) -> void:
	var enc := encounter
	if enc == null:
		var node := ctx.state.current_node()
		var row := node.row if node != null else ctx.config.early_battle_rows
		var normal := MapGenerator.normal_encounters_for_row(ctx.act_number, ctx.content, ctx.config, row)
		enc = ctx.rng().pick(&"encounter", normal) as EncounterData
	if enc == null:
		return
	ctx.state.queued_encounter = enc.id
	ctx.state.queued_encounter_rewards = rewards

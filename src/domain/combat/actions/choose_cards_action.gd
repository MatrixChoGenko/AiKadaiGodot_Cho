class_name ChooseCardsAction extends CombatAction
## ③ Domain：プレイヤーのカード選択。人間の操作中なら pending_choice を立てて WAIT を返し、
## submit_choice() の後にもう一度実行されて DONE になる。そうでなければ AutoChooser が即答する。

var choice: CardChoice


func _init(p_choice: CardChoice) -> void:
	choice = p_choice


func execute(combat: Combat) -> ActionQueue.Step:
	if choice.resolved:
		return ActionQueue.Step.DONE
	combat.focus_ctx(choice.ctx)
	# 実行時点の山から候補を作り直す（積まれてから実行までの間に山が変わりうるため）。
	combat.refresh_choice_candidates(choice)
	if choice.candidates.is_empty():
		choice.resolved = true
		return ActionQueue.Step.DONE
	if not choice.cancellable and choice.min_count >= choice.candidates.size():
		combat.resolve_choice(choice, choice.candidates.duplicate())   # 全部選ぶしかない
		return ActionQueue.Step.DONE
	if combat.waits_for_human(choice):
		combat.pending_choice = choice
		combat.emit(CombatEvent.Kind.CHOICE_REQUESTED, combat.player, null, choice.max_count)
		return ActionQueue.Step.WAIT
	combat.resolve_choice(choice, combat.chooser.choose(choice, combat.rng))
	return ActionQueue.Step.DONE

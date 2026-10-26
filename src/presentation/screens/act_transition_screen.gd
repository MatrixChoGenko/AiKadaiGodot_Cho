class_name ActTransitionScreen extends PanelScreen
## ⑤ Presentation：アクト移行（GameDesign §12.6、U15）。「第 N アクト クリア」と次のアクト名、回復量を出す。
## 「続ける」→ run.advance_act()（最大 HP の 30%（最低 1）を回復し、次のアクトのマップへ）。回復はトップバーの HP バーが伸びて見える。


var _button: Button


func enter(args: Dictionary) -> void:
	super.enter(args)
	title_label.text = "第 %d アクト クリア" % (run.state.act_index + 1)
	var acts := RunController.acts_of(run.content)
	var next := run.state.act_index + 1
	if next < acts.size():
		var label := add_text("次は 第 %d アクト「%s」" % [next + 1, acts[next].name])
		label.theme_type_variation = &"LabelLarge"
	add_text("ひと息ついて HP を %d 回復してから先へ進む。（HP %d/%d）" % [heal_amount(), Party.me(run).hp, Party.me(run).max_hp], true)
	_button = add_button("続ける", advance, footer, &"ButtonPrimary")


## 回復する量（最大 HP の act_heal_percent%、最低 1。付録 C の C38。失った分を超えない）。
func heal_amount() -> int:
	var heal := maxi(1, int(Party.me(run).max_hp * run.config.act_heal_percent / 100.0))
	return mini(heal, Party.me(run).max_hp - Party.me(run).hp)


## 次のアクトへ。協力プレイでは全員が押すまで待つ。
func advance() -> void:
	Party.act(run, CoopCommands.ADVANCE_ACT, {}, _on_advanced)


func _on_advanced(ok: bool) -> void:
	if ok and is_inside_tree() and _button != null and run.state.phase == RunPhase.Id.ACT_TRANSITION:
		_button.text = UiText.WAITING_FOR_PARTY
		_button.disabled = true

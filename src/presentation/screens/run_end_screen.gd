class_name RunEndScreen extends PanelScreen
## ⑤ Presentation：勝利 / 敗北（GameDesign §12.7、U09）。簡単なランの統計を出す（未決 #10 の回答）。
## ランのセーブは SaveManager が DEFEAT / VICTORY で削除済み。ボタンでメインメニューへ戻る。


func enter(args: Dictionary) -> void:
	super.enter(args)
	var s := run.state
	var victory := s.phase == RunPhase.Id.VICTORY
	title_label.text = "勝利！" if victory else "敗北…"
	add_text("塔の頂に辿り着いた。" if victory else "ここで力尽きた。")
	var node := s.current_node()
	var me := Party.me(run)
	var stats := PackedStringArray([
		"到達：第 %d アクト　%d 層" % [s.act_index + 1, node.row + 1 if node != null else 0],
		"勝利した戦闘：%d" % s.battles_won,
		"デッキ：%d 枚　レリック：%d 個" % [me.deck.size(), me.relics.size()],
		"所持ゴールド：%d G" % me.gold,
		"シード：%d" % s.seed_value,
	])
	if s.is_coop():
		stats.append("仲間：%s" % "、".join(_names(s)))
	add_text("\n".join(stats), true)
	add_button("メインメニューへ", main_menu_requested.emit, footer, &"ButtonPrimary")


static func _names(s: RunState) -> PackedStringArray:
	var result := PackedStringArray()
	for p in s.players:
		result.append(p.name)
	return result

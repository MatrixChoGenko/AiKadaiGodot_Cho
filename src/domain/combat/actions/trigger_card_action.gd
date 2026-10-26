class_name TriggerCardAction extends CombatAction
## ③ Domain：カードのトリガー（引いた時 / 捨てられた時 / 廃棄された時 / ターン終了時に手札にある時）を解決する。
## 積んだ時点の席を覚えておく（協力プレイで、実行時には別の席の処理中になっていることがあるため）。

var card: Card
var effects: Array[CardEffect]
var seat: PlayerSeat


func _init(p_card: Card, p_effects: Array[CardEffect], p_seat: PlayerSeat = null) -> void:
	card = p_card
	effects = p_effects
	seat = p_seat


func execute(combat: Combat) -> ActionQueue.Step:
	combat.focus(seat)
	var ctx := combat.make_context(combat.player, null, card)
	combat.push_effects(effects, ctx)
	return ActionQueue.Step.DONE

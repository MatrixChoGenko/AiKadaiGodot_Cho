class_name HookCalc extends RefCounted
## ③ Domain：ダメージ以外の補正型 Hook（BLOCK_GAIN / BLOCK_CLEAR / HEAL / STATUS_APPLY / CARD_COST /
## CARD_DESTINATION / PLAY_COUNT / TURN_ENERGY / TURN_DRAW）に渡す変更可能なデータ。使うフィールドは Hook ごとに違う。

var amount: int = 0
var source: Combatant
var target: Combatant
var card: Card
var status: StatusData
## CARD_DESTINATION：Pile.Place。
var place: int = -1
## true にすると処理を取り消す（BLOCK_CLEAR のバリケード、STATUS_APPLY のアーティファクト）。
var cancelled: bool = false
var preview: bool = false


static func make(p_amount: int, p_target: Combatant = null, p_preview: bool = false) -> HookCalc:
	var c := HookCalc.new()
	c.amount = p_amount
	c.target = p_target
	c.preview = p_preview
	return c

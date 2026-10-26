class_name DamageCalc extends RefCounted
## ③ Domain：1 回のダメージの変更可能なデータ。Combat.deal_damage() のパイプラインを流れ、Behavior が書き換える。

var amount: int
var kind: DamageEffect.Kind = DamageEffect.Kind.ATTACK
var pierce_block: bool = false
var source: Combatant
var target: Combatant
## プレビュー中。Behavior は状態を変えず、イベントも出さない。
var preview: bool = false
# —— 致死の割り込み（起死回生）——
var lethal_prevented: bool = false
var revive_heal: int = 0
# —— 結果 ——
var blocked: int = 0
var hp_lost: int = 0
var killed: bool = false


func _init(p_amount: int, p_kind: DamageEffect.Kind, p_source: Combatant, p_target: Combatant) -> void:
	amount = p_amount
	kind = p_kind
	source = p_source
	target = p_target


func is_attack() -> bool:
	return kind == DamageEffect.Kind.ATTACK

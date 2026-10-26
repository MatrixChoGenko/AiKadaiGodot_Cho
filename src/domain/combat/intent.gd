class_name Intent extends RefCounted
## ③ Domain：敵のインテント（次の行動の予告）。選ばれた行動の効果の preview() から作る（Architecture §9.4）。
## damage は実際に受けるダメージと同じパイプラインで計算する（表示 == 実際）。

enum Kind { ATTACK, ATTACK_DEFEND, ATTACK_DEBUFF, DEFEND, BUFF, DEBUFF, SPECIAL, SLEEP, UNKNOWN }

var kind: Kind = Kind.UNKNOWN
var move_id: StringName
## 1 ヒットあたりのダメージ。攻撃でなければ 0。
var damage: int = 0
var hits: int = 0
var block: int = 0
## ランダムな選択を含み、数字が正確でない（アイコンだけを出す）。
var uncertain: bool = false


func is_attack() -> bool:
	return kind in [Kind.ATTACK, Kind.ATTACK_DEFEND, Kind.ATTACK_DEBUFF]


func total_damage() -> int:
	return damage * hits


static func from_preview(move: EnemyMove, p: Preview) -> Intent:
	var i := Intent.new()
	i.move_id = move.id
	i.damage = p.attack_damage
	i.hits = p.attack_hits
	i.block = p.block
	i.uncertain = p.uncertain
	if move.intent != EnemyMove.IntentHint.AUTO:
		i.kind = (move.intent - 1) as Kind   # IntentHint は先頭に AUTO があるので 1 ずれる
	elif p.attack_hits > 0 and p.block > 0:
		i.kind = Kind.ATTACK_DEFEND
	elif p.attack_hits > 0 and p.debuffs:
		i.kind = Kind.ATTACK_DEBUFF
	elif p.attack_hits > 0:
		i.kind = Kind.ATTACK
	elif p.block > 0:
		i.kind = Kind.DEFEND
	elif p.buffs:
		i.kind = Kind.BUFF
	elif p.debuffs:
		i.kind = Kind.DEBUFF
	else:
		i.kind = Kind.SPECIAL
	return i

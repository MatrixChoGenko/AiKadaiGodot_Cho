class_name CompareCondition extends Condition
## 汎用の比較：left op right。「手札が N 枚以上」「このターンのプレイ数が N 以上」などをこれ 1 つでまかなう。

enum Op { LESS, LESS_EQUAL, EQUAL, NOT_EQUAL, GREATER_EQUAL, GREATER }

@export var left: ValueSource
@export var op: Op = Op.GREATER_EQUAL
@export var right: ValueSource


func _test(ctx: EffectContext, _subject: Combatant) -> bool:
	var a := left.evaluate(ctx)
	var b := right.evaluate(ctx)
	match op:
		Op.LESS:
			return a < b
		Op.LESS_EQUAL:
			return a <= b
		Op.EQUAL:
			return a == b
		Op.NOT_EQUAL:
			return a != b
		Op.GREATER_EQUAL:
			return a >= b
		_:
			return a > b

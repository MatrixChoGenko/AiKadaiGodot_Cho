@abstract class_name ValueSource extends Resource
## ② Content：値の出所（Architecture §6.2）。「いくつ？」に答える。ステートレス。
## ctx.combat が null（戦闘外のカード表示）でも動くこと。戦闘の状態を読むものはその場合 0 を返す。

## 誰の値を読むか。SELF = 発動者、TARGET = 現在の対象（無ければ選んだ対象）。
enum On { SELF, TARGET }

@export var min_value: int = -999999
@export var max_value: int = 999999


func evaluate(ctx: EffectContext) -> int:
	return clampi(_raw(ctx), min_value, max_value)


@abstract func _raw(ctx: EffectContext) -> int


static func unit_of(ctx: EffectContext, on: On) -> Combatant:
	return ctx.source if on == On.SELF else ctx.current_target()

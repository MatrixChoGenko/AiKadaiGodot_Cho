@abstract class_name CardEffect extends Resource
## ② Content：効果ブロックの基底（Architecture §6.1。Strategy + Composite）。
## ステートレス：同じインスタンスがすべてのカードで共有されるため、apply() でメンバ変数に書き込んではならない。

## カードテキストのプレースホルダ名（`{damage}` なら &"damage"）。空ならテキストに出さない。
@export var label: StringName
## 対象。null = 対象を取らない（発動者自身に効く効果）か、直前の効果の対象をそのまま使う。
@export var target: TargetRule


## 実行する。戦闘への変更はすべて ctx.combat の API を通す。ctx.targets は ResolveEffectAction が解決済み。
@abstract func apply(ctx: EffectContext) -> void


## 実行可能か（false だとカード全体がプレイ不可になる。コンビネータは必ず true を返す）。
func can_apply(_ctx: EffectContext) -> bool:
	return true


## プレビュー：カード面の数値とインテントを out に書く。状態を一切変更せず、乱数も消費しない。
## ctx.combat が null（戦闘外のカード表示）のときは基本値だけを書く。
func preview(_ctx: EffectContext, _out: Preview) -> void:
	pass


## 効果ツリーの走査用。コンビネータは子効果を返す（Architecture §21 ルール 12）。
func children() -> Array[CardEffect]:
	return []


## target が null なら発動者、そうでなければ解決済みの対象（生存者のみ）。
func units_or_source(ctx: EffectContext) -> Array[Combatant]:
	var result: Array[Combatant] = []
	if target == null:
		if ctx.source != null and ctx.source.is_alive():
			result.append(ctx.source)
		return result
	for u in ctx.targets:
		if u.is_alive():
			result.append(u)
	return result


## プレビューでダメージを受ける側として扱う 1 体（選んだ対象を狙う効果のときだけ。全体攻撃などは null）。
func preview_target(ctx: EffectContext) -> Combatant:
	if target is ChosenTarget and ctx.chosen != null and ctx.chosen.is_alive():
		return ctx.chosen
	return null

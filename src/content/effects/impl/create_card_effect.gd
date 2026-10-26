class_name CreateCardEffect extends CardEffect
## 指定の場所にカードを生成する（GameDesign §7.1 addCard）。敵が使う場合もプレイヤーの山に入る。

## 生成するカード。copy_source が true なら無視して、元のカードを複製する。
@export var card: CardData
@export var place: Pile.Place = Pile.Place.DISCARD
@export var count: ValueSource
## 戦闘終了で消える一時カードにする。
@export var temporary: bool = false
@export var upgraded: bool = false
@export var copy_source: bool = false


func apply(ctx: EffectContext) -> void:
	var data := ctx.card.data if copy_source and ctx.card != null else card
	if data == null:
		return
	ctx.combat.create_cards(data, place, count.evaluate(ctx), temporary, upgraded)


func preview(ctx: EffectContext, out: Preview) -> void:
	var n := count.evaluate(ctx)
	out.set_label(label, n, n)
	# 敵がプレイヤーの山にカードを入れる行動はデバフとして見せる。
	if out.muted == 0 and ctx.source != null and not ctx.source.is_player():
		out.debuffs = true

class_name RunChoiceRequest extends RefCounted
## ③ Domain：ラン中の効果が出す「プレイヤーのカード選択」のリクエスト（Architecture §10.4）。
## イベントの効果の実行後に 1 つずつ処理する。キャンセル不可（GameDesign §12.4）。

enum Kind {
	REMOVE,    ## デッキから count 枚を選んで削除する
	UPGRADE,   ## アップグレードできるカードから count 枚を選んでアップグレードする
	PICK,      ## offers から 1 枚を選んでデッキに加える
}

var kind: Kind
var count: int = 1
var offers: Array[CardData] = []


static func remove(n: int) -> RunChoiceRequest:
	var r := RunChoiceRequest.new()
	r.kind = Kind.REMOVE
	r.count = n
	return r


static func upgrade(n: int) -> RunChoiceRequest:
	var r := RunChoiceRequest.new()
	r.kind = Kind.UPGRADE
	r.count = n
	return r


static func pick(list: Array[CardData]) -> RunChoiceRequest:
	var r := RunChoiceRequest.new()
	r.kind = Kind.PICK
	r.offers = list
	return r

class_name ShopStock extends RefCounted
## ③ Domain：ショップの在庫（GameDesign §12.3）。ノードに入ったときに 1 回だけ生成する。
## 削除 / アップグレードのサービスは在庫ではなく RunController のメソッド（価格は購入回数で決まる）。

var items: Array[ShopItem] = []


func item(index: int) -> ShopItem:
	if index < 0 or index >= items.size():
		return null
	return items[index]


func of_kind(kind: ShopItem.Kind) -> Array[ShopItem]:
	var result: Array[ShopItem] = []
	for i in items:
		if i.kind == kind:
			result.append(i)
	return result

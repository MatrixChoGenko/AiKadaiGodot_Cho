class_name Pile extends RefCounted
## ② Content：カードの山と、カードを置く位置の列挙（複数のブロックで共有）。

enum Id { DRAW, HAND, DISCARD, EXHAUST }

## 新しく作ったカード / 移動するカードの置き場所。
enum Place { HAND, DRAW_TOP, DRAW_RANDOM, DRAW_BOTTOM, DISCARD, EXHAUST }

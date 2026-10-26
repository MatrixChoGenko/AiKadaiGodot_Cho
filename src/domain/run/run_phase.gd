class_name RunPhase extends RefCounted
## ③ Domain：ランのフェーズ（RunState が持つので③層に置く。Architecture §3 では flow/ だった）。メインメニューは Run の外側にあり、ここには含めない（Architecture §10.2）。
## 値は main.tscn の「フェーズ → 画面」対応表とセーブに使われるので、既存の値の順序を変えない（追加は末尾へ）。

enum Id { MAP, COMBAT, REWARD, SHOP, EVENT, REST, TREASURE, ACT_TRANSITION, DEFEAT, VICTORY }

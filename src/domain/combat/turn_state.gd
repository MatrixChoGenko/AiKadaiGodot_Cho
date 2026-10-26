class_name TurnState extends RefCounted
## ③ Domain：ターンの状態（ターン数、エネルギー、このターンのプレイ統計）。

enum Phase { SETUP, PLAYER, ENEMY, OVER }

var phase: Phase = Phase.SETUP
var number: int = 0
var energy: int = 0
## このターンの開始時に得たエネルギー（エネルギーオーブの「現在 / 上限」の上限）。
var energy_max: int = 0
## このターンにプレイしたカードの種類（プレイ順）。プレイ中のカードも含む。
var played_types: Array[int] = []
## 直前に解決し終えたカードの種類。このターンにまだ無ければ -1。
var last_type: int = -1


func start_turn() -> void:
	number += 1
	played_types.clear()
	last_type = -1


func played_count(type_filter: int) -> int:
	var n := 0
	for t in played_types:
		if type_filter == 0 or (1 << t) & type_filter != 0:
			n += 1
	return n

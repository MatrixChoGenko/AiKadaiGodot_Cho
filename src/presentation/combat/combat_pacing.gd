class_name CombatPacing extends Resource
## ⑤ Presentation：イベントの種類ごとの再生時間（秒）（GameDesign §16.1 / Architecture §14.2）。
## コードを変えずに調整できるよう Resource にしている。表に無い種類は 0 秒（ログだけ）。

## 溜まりがこの件数を超えたら比例して加速する（最大 MAX_BOOST 倍）。加速するがスキップはしない。
@export var backlog_threshold: int = 12
@export var max_boost: float = 3.0
## クリックで早送りしたときの倍率（8 倍は一瞬で終わって何が起きたか分からなかったので 1.5 倍に。2026-10-19）。
@export var fast_forward: float = 1.5
@export var durations: Dictionary[CombatEvent.Kind, float] = {
	# ターンの切り替え（StS2 の録画に合わせた。2026-10-20）：バナーと同時にドローが始まる。
	# ターン終了を押してから最初の敵が動くまで約 1.5 秒（敵のバナーが赤くなる頃）。その間に手札が炎の尾を引いて捨て札へ飛ぶ。
	CombatEvent.Kind.TURN_STARTED: 0.15,
	CombatEvent.Kind.TURN_ENDING: 0.05,
	CombatEvent.Kind.TURN_ENDED: 0.95,
	CombatEvent.Kind.ENEMY_TURN_STARTED: 0.35,
	CombatEvent.Kind.CARD_DRAWN: 0.12,
	CombatEvent.Kind.CARD_PLAYED: 0.18,
	CombatEvent.Kind.CARD_DISCARDED: 0.05,
	CombatEvent.Kind.CARD_EXHAUSTED: 0.25,
	CombatEvent.Kind.CARD_CREATED: 0.15,
	CombatEvent.Kind.CARD_MOVED: 0.06,
	CombatEvent.Kind.PILE_SHUFFLED: 0.7,
	CombatEvent.Kind.DAMAGED: 0.18,
	CombatEvent.Kind.BLOCKED: 0.1,
	CombatEvent.Kind.HEALED: 0.18,
	CombatEvent.Kind.BLOCK_GAINED: 0.15,
	CombatEvent.Kind.BLOCK_CLEARED: 0.05,
	CombatEvent.Kind.STATUS_APPLIED: 0.15,
	CombatEvent.Kind.STATUS_REMOVED: 0.05,
	CombatEvent.Kind.STATUS_TRIGGERED: 0.1,
	CombatEvent.Kind.POTION_USED: 0.25,
	CombatEvent.Kind.RELIC_TRIGGERED: 0.1,
	CombatEvent.Kind.UNIT_DIED: 0.35,
	CombatEvent.Kind.PHASE_CHANGED: 0.5,
	CombatEvent.Kind.COMBAT_ENDED: 0.3,
}


func duration_of(kind: CombatEvent.Kind) -> float:
	return durations.get(kind, 0.0)


## 溜まりの件数に応じた加速の倍率。
func backlog_boost(pending: int) -> float:
	if pending <= backlog_threshold:
		return 1.0
	return minf(max_boost, float(pending) / backlog_threshold)

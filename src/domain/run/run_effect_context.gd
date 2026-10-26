class_name RunEffectContext extends RefCounted
## ③ Domain：ラン中の効果（イベント / 休憩 / ショップ）の解決の現場（Architecture §10.4）。
## RunEffect はここを通して RunState を変える。プレイヤーのカード選択が必要な効果は requests に積み、
## RunController が効果の実行後に 1 つずつ処理させる。乱数は event ストリーム（戦闘の予約だけ encounter）。

const STREAM: StringName = &"event"

var state: RunState
var content: ContentLibrary
var config: RunConfig
var loot: LootTable
## 現在のアクトの番号（1 始まり。EncounterData.acts / EventData.acts のビットと対応する）。
var act_number: int = 1
var requests: Array[RunChoiceRequest] = []


func _init(p_state: RunState, p_content: ContentLibrary, p_config: RunConfig, p_act_number: int) -> void:
	state = p_state
	content = p_content
	config = p_config
	act_number = p_act_number
	loot = LootTable.new(content, config, state.rng)


func rng() -> RngStreams:
	return state.rng


## 効果を順に実行する。
func apply_all(effects: Array[RunEffect]) -> void:
	for e in effects:
		if e != null:
			e.apply(self)


## 条件を評価する。null = 常に成立。
func test(condition: RunCondition) -> bool:
	return condition == null or condition.test(self)

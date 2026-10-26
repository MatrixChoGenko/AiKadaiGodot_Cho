class_name RunRecorder extends RefCounted
## テスト支援：RunBot でランを最後まで進め、各チェックポイントで「セーブの中身（JSON）＋ボットの乱数状態」を記録する。
## 記録した任意のチェックポイントから resume_from() で続行し、最終状態を中断しなかった場合と比べる（M3 受け入れ基準）。
## 記録のたびに to_dict → JSON → from_dict → to_dict の往復が一致するかも検査する。

var lib: ContentLibrary
var config: RunConfig
## [reason, json, bot_rng_state] の列。
var snapshots: Array = []
var reasons: Dictionary = {}
var roundtrip_failures: PackedStringArray = PackedStringArray()
var final_json: String = ""
var bot: RunBot
var outcome: Dictionary = {}

var _run: RunController


func _init(p_lib: ContentLibrary, p_config: RunConfig = null) -> void:
	lib = p_lib
	config = p_config


func record(seed_value: int) -> RunRecorder:
	_run = RunController.new(lib, config)
	bot = RunBot.new(seed_value)
	_run.checkpoint_reached.connect(_on_checkpoint_reached)
	_run.start_new(seed_value)
	outcome = bot.play(_run)
	_run.checkpoint_reached.disconnect(_on_checkpoint_reached)
	final_json = RunFixtures.dump(_run.state)
	return self


func final_phase() -> RunPhase.Id:
	return _run.state.phase


func act_reached() -> int:
	return _run.state.act_index


## snapshots[index] からロードして最後まで進めた最終状態の JSON。
func resume_from(index: int) -> String:
	var snap: Array = snapshots[index]
	var s := RunSerializer.new()
	var state := s.from_dict(JSON.parse_string(snap[1]) as Dictionary, lib)
	if state == null:
		push_error("RunRecorder: cannot load snapshot %d: %s" % [index, s.error])
		return ""
	var run := RunController.new(lib, config)
	var b := RunBot.new(0)
	b.rng.state = snap[2]
	run.resume(state)
	var o := b.play(run)
	if o["hung"]:
		return "hung: " + b.failure
	return RunFixtures.dump(run.state)


func _on_checkpoint_reached(reason: StringName) -> void:
	reasons[reason] = int(reasons.get(reason, 0)) + 1
	var json := RunFixtures.dump(_run.state)
	snapshots.append([reason, json, bot.rng.state])
	var s := RunSerializer.new()
	var loaded := s.from_dict(JSON.parse_string(json) as Dictionary, lib)
	if loaded == null:
		roundtrip_failures.append("%s: %s" % [reason, s.error])
	elif RunFixtures.dump(loaded) != json:
		roundtrip_failures.append("%s #%d: round trip differs" % [reason, snapshots.size() - 1])

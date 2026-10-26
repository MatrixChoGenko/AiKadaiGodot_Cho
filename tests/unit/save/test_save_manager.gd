extends GutTest
## SaveManager：アトミック書き込み、.bak、破損時の復旧、チェックポイントでの保存、終了時の削除（Architecture §12.3）。

const SaveManagerScript = preload("res://src/platform/save_manager.gd")
const DIR: String = "user://test_saves"

var _lib: ContentLibrary
var _sm: Node


func before_all() -> void:
	_lib = OfficialSetup.library()


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm.set(&"run_path", DIR + "/run.json")
	_sm.call(&"delete_run")
	add_child_autofree(_sm)


func after_each() -> void:
	_sm.call(&"detach")
	_sm.call(&"delete_run")


func _path() -> String:
	return DIR + "/run.json"


func _save(state: RunState) -> bool:
	return _sm.call(&"save_run", state)


func _load() -> RunState:
	return _sm.call(&"load_run", _lib) as RunState


func _status() -> int:
	return _sm.get(&"last_status")


func test_no_save() -> void:
	assert_false(_sm.call(&"has_run"))
	assert_null(_load())
	assert_eq(_status(), SaveManagerScript.LoadStatus.NONE)


func test_save_and_load() -> void:
	var run := RunFixtures.new_run(_lib, 12)
	assert_true(_save(run.state))
	assert_true(_sm.call(&"has_run"))
	assert_false(FileAccess.file_exists(_path() + ".tmp"), "the temp file is renamed away")
	var loaded := _load()
	assert_eq(_status(), SaveManagerScript.LoadStatus.OK)
	assert_eq(RunFixtures.dump(loaded), RunFixtures.dump(run.state))


func test_second_save_keeps_a_backup() -> void:
	var run := RunFixtures.new_run(_lib, 12)
	_save(run.state)
	var first := RunFixtures.dump(run.state)
	run.state.gold = 5
	_save(run.state)
	assert_true(FileAccess.file_exists(_path() + ".bak"))
	# 本体を壊すと .bak（1 つ前のセーブ）から復旧する。
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	var loaded := _load()
	assert_eq(_status(), SaveManagerScript.LoadStatus.RECOVERED)
	assert_eq(RunFixtures.dump(loaded), first)


func test_both_corrupt() -> void:
	var run := RunFixtures.new_run(_lib, 12)
	_save(run.state)
	_save(run.state)
	for p in [_path(), _path() + ".bak"]:
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string("[]")
		f.close()
	assert_null(_load())
	assert_eq(_status(), SaveManagerScript.LoadStatus.CORRUPT)


func test_unknown_content_id_falls_back_to_backup() -> void:
	var run := RunFixtures.new_run(_lib, 12)
	_save(run.state)
	var d := RunSerializer.to_dict(run.state)
	d["relics"][0]["id"] = "removed_relic"
	_sm.call(&"save_run_dict", d)
	assert_not_null(_load())
	assert_eq(_status(), SaveManagerScript.LoadStatus.RECOVERED)
	assert_string_contains(_sm.get(&"last_error"), "removed_relic")


func test_attached_run_saves_at_checkpoints_and_deletes_at_the_end() -> void:
	var run := RunController.new(_lib)
	_sm.call(&"attach", run)
	run.start_new(3)
	assert_true(_sm.call(&"has_run"), "saved at returned_to_map")
	run.enter_node(run.choices()[0].id)
	var loaded := _load()
	assert_eq(loaded.phase, RunPhase.Id.COMBAT, "saved at combat_started")
	assert_eq(loaded.active_encounter, run.state.active_encounter)
	run.abandon()
	assert_false(_sm.call(&"has_run"), "deleted on defeat")


## Windows で書いた直後のファイルの名前の変更がまれに失敗する（ほかのプロセスが一瞬開いている）。少し待ってやり直す。
func test_file_operation_is_retried_after_transient_failures() -> void:
	var calls: Array[int] = [0]
	var flaky := func() -> Error:
		calls[0] += 1
		return OK if calls[0] >= 3 else ERR_FILE_CANT_WRITE
	assert_eq(_sm.call(&"_retry", flaky), OK)
	assert_eq(calls[0], 3, "stops retrying once it succeeds")
	calls[0] = -100
	assert_eq(_sm.call(&"_retry", flaky), ERR_FILE_CANT_WRITE, "gives up after the retries")
	assert_eq(calls[0], -100 + 1 + SaveManagerScript.FILE_OP_RETRIES)

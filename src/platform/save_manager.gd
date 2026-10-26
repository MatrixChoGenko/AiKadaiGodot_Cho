extends Node
## ① Platform / Autoload `SaveManager`：ランのセーブの読み書き（Architecture §12.1・§12.3）。
## - attach(run) で RunController.checkpoint_reached を購読して保存し、DEFEAT / VICTORY でセーブを削除する。
## - 書き込みはアトミック：.tmp に書く → 旧ファイルを .bak にリネーム → .tmp を正式名にリネーム。
## - Windows では書いた直後のファイルの名前の変更 / 削除がまれに失敗する（ほかのプロセス（ウイルス対策・インデクサー）が
##   一瞬だけ開いている）ので、少し待って数回やり直す（M5 の再起動テストで実測）。
## - 読み込みは本体 → .bak の順に試す。どちらも読めなければ status = CORRUPT にし、例外は投げない。
## プロファイル（ランをまたぐデータ）は今は使わない。

enum LoadStatus { NONE, OK, RECOVERED, CORRUPT }

const RUN_PATH: String = "user://saves/run.json"
const PROFILE_PATH: String = "user://saves/profile.json"
## 名前の変更 / 削除をやり直す回数と、1 回目の待ち時間（回ごとに伸ばす）。
const FILE_OP_RETRIES: int = 6
const FILE_OP_RETRY_MS: int = 15

## テストで差し替えられるようにする。
var run_path: String = RUN_PATH
## 直前の load_run() の結果。
var last_status: LoadStatus = LoadStatus.NONE
## 直前の load_run() が失敗した理由（読めなかったファイルごと）。
var last_error: String = ""

var _run: RunController


## ラン 1 つに接続する（前の接続は外す）。
func attach(run: RunController) -> void:
	detach()
	_run = run
	_run.checkpoint_reached.connect(_on_run_checkpoint_reached)
	_run.phase_changed.connect(_on_run_phase_changed)


func detach() -> void:
	if _run != null:
		_run.checkpoint_reached.disconnect(_on_run_checkpoint_reached)
		_run.phase_changed.disconnect(_on_run_phase_changed)
	_run = null


func has_run() -> bool:
	return FileAccess.file_exists(run_path) or FileAccess.file_exists(_bak_path())


func save_run(state: RunState) -> bool:
	return save_run_dict(RunSerializer.to_dict(state))


## アトミックに書き込む。失敗したら false（旧ファイルは残る）。
func save_run_dict(d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(_abs(run_path.get_base_dir()))
	var tmp := run_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		Log.error(&"save", "cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if FileAccess.file_exists(run_path):
		if FileAccess.file_exists(_bak_path()):
			_retry(func() -> Error: return DirAccess.remove_absolute(_abs(_bak_path())))
		var err := _retry(func() -> Error: return DirAccess.rename_absolute(_abs(run_path), _abs(_bak_path())))
		if err != OK:
			Log.error(&"save", "cannot rename to .bak (%s)" % error_string(err))
			return false
	var err2 := _retry(func() -> Error: return DirAccess.rename_absolute(_abs(tmp), _abs(run_path)))
	if err2 != OK:
		Log.error(&"save", "cannot rename .tmp (%s)" % error_string(err2))
		return false
	return true


## 本体 → .bak の順に読む。読めなければ null（last_status で理由がわかる）。
func load_run(content: ContentLibrary) -> RunState:
	last_error = ""
	if not has_run():
		last_status = LoadStatus.NONE
		return null
	var paths := [run_path, _bak_path()]
	for i in paths.size():
		var state := _load_file(paths[i], content)
		if state != null:
			last_status = LoadStatus.OK if i == 0 else LoadStatus.RECOVERED
			if i > 0:
				Log.warn(&"save", "run save was unreadable; recovered from .bak (%s)" % last_error)
			return state
	last_status = LoadStatus.CORRUPT
	Log.warn(&"save", "run save is corrupt: %s" % last_error)
	return null


func delete_run() -> void:
	for p: String in [run_path, _bak_path(), run_path + ".tmp"]:
		if FileAccess.file_exists(p):
			_retry(func() -> Error: return DirAccess.remove_absolute(_abs(p)))


func _load_file(path: String, content: ContentLibrary) -> RunState:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		last_error += "%s: invalid JSON. " % path.get_file()
		return null
	var serializer := RunSerializer.new()
	var state := serializer.from_dict(json.data as Dictionary, content)
	if state == null:
		last_error += "%s: %s. " % [path.get_file(), serializer.error]
	return state


## ファイル操作（Error を返す Callable）を、失敗したら少し待ってやり直す。最後の結果を返す。
func _retry(op: Callable) -> Error:
	var err: Error = op.call()
	for i in FILE_OP_RETRIES:
		if err == OK:
			break
		OS.delay_msec(FILE_OP_RETRY_MS * (i + 1))
		err = op.call()
	return err


func _bak_path() -> String:
	return run_path + ".bak"


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _on_run_checkpoint_reached(reason: StringName) -> void:
	if save_run(_run.state):
		Log.debug(&"save", "saved at %s" % reason)


func _on_run_phase_changed(phase: RunPhase.Id) -> void:
	if phase in [RunPhase.Id.DEFEAT, RunPhase.Id.VICTORY]:
		delete_run()


# —— 協力プレイ（GameDesign §21）——
# ホストだけが書く。1 人プレイのセーブとは別のファイル。ラン中は run_path をこちらに切り替えて attach する。

const COOP_RUN_PATH: String = "user://saves/coop_run.json"

## テストで差し替えられるようにする。
var coop_path: String = COOP_RUN_PATH
var _solo_path: String = ""


## 協力プレイのランの間だけ、オートセーブの書き先を協力プレイのファイルにする。
func use_coop_path(on: bool) -> void:
	if on:
		if _solo_path == "":
			_solo_path = run_path
		run_path = coop_path
	elif _solo_path != "":
		run_path = _solo_path
		_solo_path = ""


func has_coop_run() -> bool:
	return FileAccess.file_exists(coop_path) or FileAccess.file_exists(coop_path + ".bak")


## 協力プレイのセーブを Dictionary のまま読む（参加者へそのまま送るため）。本体 → .bak の順。読めなければ空。
func load_coop_dict() -> Dictionary:
	for path: String in [coop_path, coop_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			return json.data as Dictionary
	return {}

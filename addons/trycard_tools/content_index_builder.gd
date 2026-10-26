@tool
class_name ContentIndexBuilder extends RefCounted
## コンテンツインデックスの再構築（Architecture §17.2）。
## res://content 以下の .tres を走査して種類ごとに ContentLibrary に登録し、content_library.tres に保存する。
## 並び順はファイルパス順（毎回同じ結果になる）。ブロックのプリセットなど、どの種類にも当たらない .tres は無視する。

const CONTENT_DIR: String = "res://content"
const LIBRARY_PATH: String = "res://content/content_library.tres"


## 走査してインデックスを作る（保存はしない）。
static func collect(dir_path: String = CONTENT_DIR) -> ContentLibrary:
	var lib := ContentLibrary.new()
	var paths := list_resources(dir_path)
	paths.sort()
	for path in paths:
		if path == LIBRARY_PATH:
			continue
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res is CardData:
			lib.cards.append(res as CardData)
		elif res is StatusData:
			lib.statuses.append(res as StatusData)
		elif res is KeywordData:
			lib.keywords.append(res as KeywordData)
		elif res is RelicData:
			lib.relics.append(res as RelicData)
		elif res is PotionData:
			lib.potions.append(res as PotionData)
		elif res is EnemyData:
			lib.enemies.append(res as EnemyData)
		elif res is EncounterData:
			lib.encounters.append(res as EncounterData)
		elif res is EventData:
			lib.events.append(res as EventData)
		elif res is ActData:
			lib.acts.append(res as ActData)
		elif res is RunConfig:
			if lib.config != null:
				push_error("ContentIndexBuilder: more than one RunConfig (%s)" % path)
			lib.config = res as RunConfig
	return lib


## 走査してインデックスを作り、content_library.tres に保存する。
static func rebuild() -> ContentLibrary:
	var lib := collect()
	var err := ResourceSaver.save(lib, LIBRARY_PATH)
	if err != OK:
		push_error("ContentIndexBuilder: failed to save %s (%s)" % [LIBRARY_PATH, error_string(err)])
	return lib


static func list_resources(dir_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file in dir.get_files():
		if file.ends_with(".tres"):
			result.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		result.append_array(list_resources(dir_path.path_join(sub)))
	return result

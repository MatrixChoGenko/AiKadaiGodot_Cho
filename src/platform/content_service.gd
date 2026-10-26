extends Node
## ① Platform / Autoload `Content`：`content/content_library.tres` を読み込み、id での検索を提供する。
## ルール層（②③④）はこの Autoload を参照せず、ここから受け取った ContentLibrary を引数で使う。

const LIBRARY_PATH: String = "res://content/content_library.tres"

var library: ContentLibrary


func _ready() -> void:
	library = load(LIBRARY_PATH) as ContentLibrary
	if library == null:
		Log.error(&"content", "failed to load %s (rebuild the content index)" % LIBRARY_PATH)
		return
	Log.info(&"content", "loaded %d cards, %d enemies, %d events" % [library.cards.size(), library.enemies.size(), library.events.size()])


func card(id: StringName) -> CardData:
	return library.card(id)


func relic(id: StringName) -> RelicData:
	return library.relic(id)


func potion(id: StringName) -> PotionData:
	return library.potion(id)


func config() -> RunConfig:
	return library.config

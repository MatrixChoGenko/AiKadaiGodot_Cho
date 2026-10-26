extends SceneTree
## カードの .tres に絵（assets/textures/card_art/<id>.png）と見せる位置（art_focus）を入れる。
## 先に python -I tools/card_art.py で絵を取り込んでおく。強化版（id_plus）は基本版と同じ絵。
## 使い方: Godot --headless --path <project> -s tools/card_art.gd（今ある content/ を書き換える。seed_content も apply() を使う）。

const ART_DIR: String = "res://assets/textures/card_art/"
## 中央（0.5）以外で見せたい位置。0 = 上端、1 = 下端（窓 比 1.24 のとき上下 19% が隠れる）。
const FOCUS: Dictionary[String, float] = {
	"adrenaline": 0.4,
	"cast_off": 0.4,
	"catalyst": 0.4,
	"corrode": 0.4,
	"crescendo": 0.4,
	"curse_eater": 0.4,
	"dazed": 0.4,
	"defend": 0.6,
	"demon_form": 0.4,
	"entropy": 0.4,
	"finisher": 0.25,
	"from_the_ashes": 0.4,
	"gather_strength": 0.3,
	"inflame": 0.3,
	"iron_wave": 0.8,
	"last_ditch": 0.3,
	"offering": 0.3,
	"overload": 0.4,
	"pain_conversion": 0.4,
	"phantom_blade": 0.6,
	"poison_stab": 0.7,
	"reinforcements": 0.4,
	"siphon": 0.4,
	"sprint": 0.6,
	"strike": 0.7,
	"time_bomb": 0.4,
	"vigil": 0.4,
}


## 絵があれば入れる。戻り値 = 入れたか。
static func apply(card: CardData) -> bool:
	var base := String(card.id).trim_suffix("_plus")
	var path := ART_DIR + base + ".png"
	if not ResourceLoader.exists(path):
		return false
	card.art = load(path)
	card.art_focus = FOCUS.get(base, 0.5)
	return true


func _init() -> void:
	var count := 0
	for path in ContentIndexBuilder.list_resources("res://content/cards"):
		var card := load(path) as CardData
		if card != null and apply(card):
			ResourceSaver.save(card, path)
			count += 1
	print("card_art: %d cards" % count)
	quit()

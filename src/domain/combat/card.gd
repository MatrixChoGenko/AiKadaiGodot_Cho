class_name Card extends RefCounted
## ③ Domain：ラン中の 1 枚のカード。アップグレード = data を差し替える。
## 戦闘中だけの値（コストの増減、成長値、保留ターン数など）は reset_combat_mods() で戦闘終了時に戻す。

var uid: int
var data: CardData
## 戦闘中に生成され、戦闘終了で消える。プレイ後は廃棄札へ行く。
var temporary: bool = false

# —— 戦闘中だけの値 ——
var cost_delta_combat: int = 0
var cost_delta_turn: int = 0
var growth: int = 0
var retained_turns: int = 0
var retain_this_turn: bool = false


func _init(p_uid: int, p_data: CardData, p_temporary: bool = false) -> void:
	uid = p_uid
	data = p_data
	temporary = p_temporary


func has_keyword(k: CardData.Keyword) -> bool:
	return data.keywords & k != 0


func type_bit() -> int:
	return 1 << data.type


func matches(type_filter: int) -> bool:
	return type_filter == 0 or type_bit() & type_filter != 0


func can_upgrade() -> bool:
	return data.upgraded != null


func upgrade() -> bool:
	if data.upgraded == null:
		return false
	data = data.upgraded
	return true


func reset_combat_mods() -> void:
	cost_delta_combat = 0
	cost_delta_turn = 0
	growth = 0
	retained_turns = 0
	retain_this_turn = false


func _to_string() -> String:
	return "%s#%d" % [data.id, uid]

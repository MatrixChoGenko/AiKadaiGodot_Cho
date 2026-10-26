class_name ActorCatalog extends RefCounted
## ⑤ Presentation：戦闘の 3D アクターの見た目の表（モデル・武器・動作ごとのクリップ）。素材は KayKit（CC0、assets/models/）。
## 敵は EnemyData.id で引く。表に無い敵は 3D を出さず、立ち絵（GlyphBadge）のまま表示する。
## 動作（ACT_*）→ クリップ名。クリップ名は「ライブラリ名/クリップ名」（ライブラリ名 = assets/models/animations/ のファイル名）。
## 攻撃（attack）は配列で、連続攻撃のたびに順に使う。moves は行動 id ごとの上書き（動作 → クリップ）。

const ACT_IDLE: StringName = &"idle"
const ACT_ATTACK: StringName = &"attack"
const ACT_BLOCK: StringName = &"block"
const ACT_BUFF: StringName = &"buff"
const ACT_DEBUFF: StringName = &"debuff"
const ACT_CAST: StringName = &"cast"
const ACT_HIT: StringName = &"hit"
const ACT_GUARD_HIT: StringName = &"guard_hit"
const ACT_DEATH: StringName = &"death"
const ACT_DEATH_POSE: StringName = &"death_pose"
const ACT_SPAWN: StringName = &"spawn"

const MODELS: String = "res://assets/models/characters/%s.glb"
const WEAPONS: String = "res://assets/models/weapons/%s.gltf"
const ANIMS: String = "res://assets/models/animations/%s.glb"

## 骨格ごとに読み込むアニメーションライブラリ。
const RIG_LIBRARIES: Dictionary[StringName, Array] = {
	&"medium": ["Rig_Medium_General", "Rig_Medium_CombatMelee", "Rig_Medium_CombatRanged", "Rig_Medium_Special"],
	&"large": ["Rig_Large_General", "Rig_Large_CombatMelee", "Rig_Large_Simulation"],
}

## 攻撃の当たる瞬間（クリップの先頭からの秒）。手の速さが最大になる時刻を実測して少し後ろにずらした値。表に無いクリップは長さの 40%。
const IMPACT: Dictionary[StringName, float] = {
	&"Rig_Medium_CombatMelee/Melee_1H_Attack_Chop": 0.6,
	&"Rig_Medium_CombatMelee/Melee_1H_Attack_Slice_Diagonal": 0.45,
	&"Rig_Medium_CombatMelee/Melee_1H_Attack_Slice_Horizontal": 0.3,
	&"Rig_Medium_CombatMelee/Melee_1H_Attack_Stab": 0.4,
	&"Rig_Medium_CombatMelee/Melee_Block_Attack": 0.45,
	&"Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Chop": 0.57,
	&"Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Slice": 0.57,
	&"Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Stab": 0.4,
	&"Rig_Medium_CombatRanged/Ranged_Magic_Shoot": 0.3,
	&"Rig_Medium_CombatRanged/Ranged_Magic_Spellcasting": 0.35,
	&"Rig_Medium_CombatRanged/Ranged_Magic_Spellcasting_Long": 1.2,
	&"Rig_Medium_CombatRanged/Ranged_Magic_Raise": 0.8,
	&"Rig_Medium_General/Throw": 0.64,
	&"Rig_Medium_General/Use_Item": 0.6,
	&"Rig_Medium_CombatMelee/Melee_Block": 0.25,
	&"Rig_Medium_Special/Skeletons_Taunt": 0.6,
	&"Rig_Large_CombatMelee/Melee_2H_Attack": 0.5,
	&"Rig_Large_CombatMelee/Melee_2H_Slam": 0.95,
	&"Rig_Large_CombatMelee/Melee_Block": 0.25,
	&"Rig_Large_Simulation/Flexing": 1.2,
}

## 共通のクリップ（骨格ごと）。各キャラの表で上書きする。
const _MEDIUM_BASE: Dictionary = {
	ACT_IDLE: "Rig_Medium_General/Idle_A", ACT_HIT: "Rig_Medium_General/Hit_A",
	ACT_GUARD_HIT: "Rig_Medium_CombatMelee/Melee_Block_Hit", ACT_BLOCK: "Rig_Medium_CombatMelee/Melee_Block",
	ACT_BUFF: "Rig_Medium_CombatRanged/Ranged_Magic_Raise", ACT_DEBUFF: "Rig_Medium_General/Throw",
	ACT_CAST: "Rig_Medium_General/Use_Item",
	ACT_DEATH: "Rig_Medium_General/Death_A", ACT_DEATH_POSE: "Rig_Medium_General/Death_A_Pose",
	ACT_SPAWN: "Rig_Medium_General/Spawn_Ground",
}
const _SKELETON_BASE: Dictionary = {
	ACT_IDLE: "Rig_Medium_Special/Skeletons_Idle", ACT_BUFF: "Rig_Medium_Special/Skeletons_Taunt",
	ACT_DEATH: "Rig_Medium_Special/Skeletons_Death", ACT_DEATH_POSE: "Rig_Medium_Special/Skeletons_Death_Pose",
	ACT_SPAWN: "Rig_Medium_Special/Skeletons_Awaken_Standing",
}
const _LARGE_BASE: Dictionary = {
	ACT_IDLE: "Rig_Large_General/Idle_A", ACT_HIT: "Rig_Large_General/Hit_A",
	ACT_GUARD_HIT: "Rig_Large_CombatMelee/Melee_Block_Hit", ACT_BLOCK: "Rig_Large_CombatMelee/Melee_Block",
	ACT_BUFF: "Rig_Large_Simulation/Flexing", ACT_DEBUFF: "Rig_Large_CombatMelee/Melee_2H_Slam",
	ACT_CAST: "Rig_Large_Simulation/Flexing",
	ACT_DEATH: "Rig_Large_General/Death_A", ACT_DEATH_POSE: "Rig_Large_General/Death_A_Pose",
	ACT_SPAWN: "Rig_Large_General/Idle_A",
}

## プレイヤー（GameDesign §15.4 の「自」）。in_place = 踏み込まずにその場で攻撃する、rate = 攻撃・動作のクリップの再生倍率
## （どちらもカードを続けて出すテンポを優先。既定は StageActor.ACTION_RATE）。
const PLAYER: Dictionary = {
	model = "Knight", rig = &"medium", right = "sword_1handed", left = "shield_badge_color", in_place = true, rate = 1.7,
	clips = {
		ACT_ATTACK: ["Rig_Medium_CombatMelee/Melee_1H_Attack_Slice_Diagonal", "Rig_Medium_CombatMelee/Melee_1H_Attack_Chop",
				"Rig_Medium_CombatMelee/Melee_1H_Attack_Slice_Horizontal"],
		ACT_BUFF: "Rig_Medium_CombatRanged/Ranged_Magic_Raise",
		ACT_CAST: "Rig_Medium_General/Use_Item",
	},
}

## 敵（EnemyData.id → 見た目）。scale はモデルの拡大率、ranged は遠隔（踏み込まずにその場で攻撃する）。
const ENEMIES: Dictionary[StringName, Dictionary] = {
	&"louse": {
		model = "Skeleton_Minion", rig = &"medium", right = "Skeleton_Blade", base = "skeleton",
		clips = {ACT_ATTACK: ["Rig_Medium_CombatMelee/Melee_1H_Attack_Chop"]},
	},
	&"slime": {
		model = "Skeleton_Rogue", rig = &"medium", right = "Skeleton_Dagger", left = "Skeleton_Dagger", base = "skeleton",
		clips = {ACT_ATTACK: ["Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Stab", "Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Slice"]},
	},
	&"cultist": {
		model = "Skeleton_Mage", rig = &"medium", right = "Skeleton_Staff", base = "skeleton", ranged = true,
		clips = {ACT_ATTACK: ["Rig_Medium_CombatRanged/Ranged_Magic_Shoot"], ACT_BUFF: "Rig_Medium_CombatRanged/Ranged_Magic_Raise"},
	},
	&"jawworm": {
		model = "Skeleton_Warrior", rig = &"medium", right = "Skeleton_Axe", left = "Skeleton_Shield_Small_A", base = "skeleton",
		clips = {ACT_ATTACK: ["Rig_Medium_CombatMelee/Melee_1H_Attack_Chop"]},
		moves = {&"thrash": {ACT_ATTACK: ["Rig_Medium_CombatMelee/Melee_Block_Attack"]}},
	},
	&"gremlin_nob": {
		model = "Skeleton_Golem", rig = &"large", right = "Skeleton_Golem_Axe_Large", scale = 0.75,
		clips = {ACT_ATTACK: ["Rig_Large_CombatMelee/Melee_2H_Attack"]},
		moves = {&"stomp": {ACT_ATTACK: ["Rig_Large_CombatMelee/Melee_2H_Slam"]}},
	},
	&"guardian": {
		model = "Necromancer", rig = &"medium", right = "Skeleton_Scythe", base = "skeleton", ranged = true, scale = 1.25,
		clips = {
			ACT_ATTACK: ["Rig_Medium_CombatRanged/Ranged_Magic_Shoot"], ACT_BLOCK: "Rig_Medium_CombatRanged/Ranged_Magic_Raise",
			ACT_BUFF: "Rig_Medium_CombatRanged/Ranged_Magic_Raise", ACT_DEBUFF: "Rig_Medium_CombatRanged/Ranged_Magic_Spellcasting",
		},
		moves = {
			&"fury": {ACT_ATTACK: ["Rig_Medium_CombatRanged/Ranged_Magic_Spellcasting"]},
			&"doom": {ACT_ATTACK: ["Rig_Medium_CombatRanged/Ranged_Magic_Spellcasting_Long"]},
		},
	},
}


## 見た目の表を返す（clips は骨格の共通表と合成済み）。無ければ空の辞書。
static func spec_for_enemy(enemy_id: StringName) -> Dictionary:
	return _resolve(ENEMIES[enemy_id]) if ENEMIES.has(enemy_id) else {}


static func spec_for_player() -> Dictionary:
	return _resolve(PLAYER)


static func impact_of(clip: StringName, length: float) -> float:
	return IMPACT.get(clip, length * 0.4)


static func _resolve(raw: Dictionary) -> Dictionary:
	var spec := raw.duplicate(true)
	var clips: Dictionary = {}
	clips.merge(_LARGE_BASE if raw["rig"] == &"large" else _MEDIUM_BASE, true)
	if raw.get("base", "") == "skeleton":
		clips.merge(_SKELETON_BASE, true)
	clips.merge(raw["clips"], true)
	spec["clips"] = clips
	return spec

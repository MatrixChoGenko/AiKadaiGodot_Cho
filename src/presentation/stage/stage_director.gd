class_name StageDirector extends RefCounted
## ⑤ Presentation：戦闘のイベントを 3D アクターの動作に翻訳する（Architecture §14.6）。CombatPresenter が 1 件ごとに呼ぶ。
## - lead_in(e)：e を見せる「前」に待つ秒。攻撃の 1 撃（BLOCKED / DAMAGED、種類 ATTACK）は、ここで振りかぶって当たる瞬間まで待たせる。
## - after(e)：e を見せた「後」に必要な秒。行動の始まり（CARD_PLAYED / ENEMY_TURN_STARTED）で攻撃以外の動作をし、
##   効果が出る瞬間まで待たせる。被弾・死亡の反応もここ。
## 攻撃の動作はダメージのイベント（1 撃ごと）から、攻撃以外の動作は行動の始まりから決める。どちらも 1 行動に 1 回ではなく、
## 多段攻撃は撃数だけ振る。返す秒は「再生の時間」（Presenter の速度を掛ける前）。

## 打撃のエフェクトを出す高さ（身長の割合）と、体の中心から攻撃側へ寄せる量（身長の割合）。
const HIT_FX_HEIGHT: float = 0.55
const HIT_FX_FRONT: float = 0.12
## 打撃のエフェクトの大きさ = MIN + PER_RATIO × (ダメージ / 最大 HP)（GameDesign §16.2 の「打撃の強さ」）。
const HIT_FX_SIZE_MIN: float = 0.9
const HIT_FX_SIZE_PER_RATIO: float = 1.2
## 状態異常が付いた（増えた）ときのエフェクト：ステータスの id → [エフェクト, 出す高さ（身長の割合）]。表に無いステータスは何も出さない。
const STATUS_FX: Dictionary[StringName, Array] = {
	&"poison": [&"poison", 0.55],
	&"strength": [&"strength", 0.0],
	&"weak": [&"weak", 0.55],
	&"vulnerable": [&"vulnerable", 0.55],
}

var _stage: BattleStage
var _screen: CombatScreen
## 直前に見せた BLOCKED（同じ 1 撃の DAMAGED が続く。振りかぶりは 1 回だけ）。
var _last_blocked: CombatEvent


func _init(stage: BattleStage, screen: CombatScreen) -> void:
	_stage = stage
	_screen = screen


func lead_in(e: CombatEvent) -> float:
	match e.kind:
		CombatEvent.Kind.BLOCKED, CombatEvent.Kind.DAMAGED:
			if e.kind == CombatEvent.Kind.DAMAGED and _same_hit(_last_blocked, e):
				return 0.0
			var kind: DamageEffect.Kind = e.snapshot.get("kind", DamageEffect.Kind.ATTACK)
			if kind != DamageEffect.Kind.ATTACK or e.source_uid < 0 or e.source_uid == e.target_uid:
				return 0.0
			var attacker := _stage.actor(e.source_uid)
			if attacker == null:
				return 0.0
			return attacker.strike(_stage.actor(e.target_uid))
	return 0.0


func after(e: CombatEvent) -> float:
	_last_blocked = e if e.kind == CombatEvent.Kind.BLOCKED else null
	match e.kind:
		CombatEvent.Kind.COMBAT_STARTED:
			for uid in _alive_enemy_uids():
				var a := _stage.actor(uid)
				if a != null:
					a.perform(ActorCatalog.ACT_SPAWN)
					_stage.spawn_on(&"spawn", a, 0.0)
		CombatEvent.Kind.CARD_PLAYED:
			var player := _stage.actor(e.source_uid)
			var card := _screen.find_card(e.value)
			if player == null or card == null:
				return 0.0
			player.set_move(&"")
			match card.data.type:
				CardData.Type.ATTACK:
					return 0.0
				CardData.Type.POWER:
					return player.perform(ActorCatalog.ACT_BUFF)
			return player.perform(ActorCatalog.ACT_BLOCK if _has_block(card.data.on_play) else ActorCatalog.ACT_CAST)
		CombatEvent.Kind.ENEMY_TURN_STARTED:
			var enemy := _stage.actor(e.source_uid)
			if enemy == null:
				return 0.0
			enemy.set_move(e.id)
			var intent: Intent.Kind = e.snapshot.get("intent", Intent.Kind.UNKNOWN)
			match intent:
				Intent.Kind.ATTACK, Intent.Kind.ATTACK_DEFEND, Intent.Kind.ATTACK_DEBUFF:
					return 0.0
				Intent.Kind.DEFEND:
					return enemy.perform(ActorCatalog.ACT_BLOCK)
				Intent.Kind.BUFF:
					return enemy.perform(ActorCatalog.ACT_BUFF)
				Intent.Kind.DEBUFF:
					return enemy.perform(ActorCatalog.ACT_DEBUFF)
			return enemy.perform(ActorCatalog.ACT_CAST)
		CombatEvent.Kind.BLOCKED:
			var target := _stage.actor(e.target_uid)
			if target != null:
				target.react(true)
				_hit_fx(&"guard", e, target, 1.0)
				if e.snapshot.get("block", 1) == 0:
					_stage.spawn_on(&"shatter", target, 0.5)   # 受けきれずにブロックが割れた
		CombatEvent.Kind.DAMAGED:
			var target := _stage.actor(e.target_uid)
			if target != null and e.value > 0:
				if not (e.flags & CombatEvent.FLAG_LETHAL):
					target.react(false)
				var kind: DamageEffect.Kind = e.snapshot.get("kind", DamageEffect.Kind.ATTACK)
				if kind == DamageEffect.Kind.ATTACK:
					var max_hp: float = maxf(1.0, e.snapshot.get("max_hp", 1))
					_hit_fx(&"hit", e, target, HIT_FX_SIZE_MIN + HIT_FX_SIZE_PER_RATIO * minf(1.0, e.value / max_hp))
				elif kind == DamageEffect.Kind.STATUS:
					_stage.spawn_on(&"poison_tick", target, 0.5)
		CombatEvent.Kind.BLOCK_GAINED:
			var target := _stage.actor(e.target_uid)
			if target != null and not target.dead:
				_stage.spawn_on(&"block", target, 0.5)
		CombatEvent.Kind.BLOCK_CLEARED:
			var target := _stage.actor(e.target_uid)
			if target != null and not target.dead:
				_stage.spawn_on(&"shatter", target, 0.5)
		CombatEvent.Kind.HEALED:
			var target := _stage.actor(e.target_uid)
			if target != null and not target.dead:
				_stage.spawn_on(&"heal", target, 0.3)
		CombatEvent.Kind.STATUS_APPLIED:
			var target := _stage.actor(e.target_uid)
			if target != null and not target.dead and e.value > 0 and STATUS_FX.has(e.id):
				var fx: Array = STATUS_FX[e.id]
				_stage.spawn_on(fx[0], target, fx[1])
		CombatEvent.Kind.UNIT_DIED:
			var target := _stage.actor(e.target_uid)
			if target != null:
				target.die()
	return 0.0


## 再生を経ずにモデルの状態へ合わせる（倒れているべきユニットを倒す）。
func sync_unit(unit: Combatant) -> void:
	var a := _stage.actor(unit.uid)
	if a != null and not unit.is_alive():
		a.set_dead_pose()


## 打撃のエフェクト（hit / guard）を、攻撃した側から見た相手の体の手前に出す。破片は攻撃の向きへ飛ぶ。
func _hit_fx(kind: StringName, e: CombatEvent, target: StageActor, size: float) -> void:
	var attacker := _stage.actor(e.source_uid) if e.source_uid != e.target_uid else null
	var dir := signf(target.position.x - attacker.position.x) if attacker != null else -target.facing
	if dir == 0.0:
		dir = -target.facing
	var at := BattleStage.body_point(target, HIT_FX_HEIGHT)
	at.x -= dir * target.height * HIT_FX_FRONT
	_stage.spawn_fx(kind, at, dir, size)


func _same_hit(blocked: CombatEvent, damaged: CombatEvent) -> bool:
	return blocked != null and blocked.source_uid == damaged.source_uid and blocked.target_uid == damaged.target_uid


func _alive_enemy_uids() -> Array[int]:
	var uids: Array[int] = []
	for e in _screen.ctl.combat.alive_enemies():
		uids.append(e.uid)
	return uids


## カードの効果にブロックを得るものがあるか（入れ子は見ない。見た目の選択に使うだけ）。
static func _has_block(effects: Array[CardEffect]) -> bool:
	for fx in effects:
		if fx is BlockEffect:
			return true
	return false

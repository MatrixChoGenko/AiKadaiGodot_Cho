# TryCard — コードアーキテクチャ文書（Godot 4 / GDScript）

> バージョン：v0.1（ドラフト・確認待ち）　日付：2026-10-19
> 対象読者：開発に参加するプログラマ。ルールとコンテンツは `GameDesign.md`、スケジュールは `DevelopmentPlan.md` を参照。
> 本書が定めるもの：レイヤー、ディレクトリ、中核クラス、デザインパターン、データの流れ、拡張方法、必ず守るルール。コード片は**骨組み**であり、インターフェースと責務を固定するためのもので、最終的な実装ではない。

---

## 目次

1. [設計目標](#1-設計目標)
2. [レイヤー概観](#2-レイヤー概観)
3. [ディレクトリ構成](#3-ディレクトリ構成)
4. [Autoload（グローバルサービス）](#4-autoloadグローバルサービス)
5. [コンテンツ層：Resource 駆動のデータ](#5-コンテンツ層resource-駆動のデータ)
6. [効果ブロック：Strategy + Composite](#6-効果ブロックstrategy--composite)
7. [戦闘エンジン](#7-戦闘エンジン)
8. [補正とトリガー：Behavior パイプライン](#8-補正とトリガーbehavior-パイプライン)
9. [敵 AI](#9-敵-ai)
10. [ラン進行（Run）](#10-ラン進行run)
11. [乱数](#11-乱数)
12. [セーブ](#12-セーブ)
13. [プレゼンテーション層のアーキテクチャ](#13-プレゼンテーション層のアーキテクチャ)
14. [戦闘画面の詳細](#14-戦闘画面の詳細)
15. [エフェクト・効果音・時間](#15-エフェクト効果音時間)
16. [ローカライズ](#16-ローカライズ)
17. [コンテンツのワークフローとツール](#17-コンテンツのワークフローとツール)
18. [テストアーキテクチャ](#18-テストアーキテクチャ)
19. [デバッグツール](#19-デバッグツール)
20. [拡張ガイド（X を追加したい）](#20-拡張ガイドx-を追加したい)
21. [ルール一覧（必須）](#21-ルール一覧必須)
22. [命名とコーディング規約](#22-命名とコーディング規約)
23. [協力プレイ（LAN）：ロックステップ](#23-協力プレイlanロックステップ)

---

## 1. 設計目標

| 目標 | 方法 |
|---|---|
| **コードなしでコンテンツを拡張** | カード / ステータス / レリック / ポーション / 敵 / イベントはすべて `.tres` Resource で、組み合わせ可能なブロック（効果、値の出所、条件、対象ルール）で構成する。Godot の Inspector がそのままコンテンツエディタになる |
| **ルールが画面なしで動く** | ルール層はすべて `RefCounted` で SceneTree に依存しない。ヘッドレスでテストでき、数千戦の自動対戦も回せる |
| **決定性** | すべての乱数は名前付きの乱数ストリームを通す。プレビュー経路は乱数に触れない。同じシード + 同じ操作 = 同じ結果 |
| **表現とルールの分離** | ルール層は同期的に最後まで実行してイベントログを出力する。表現層はそのログを自分のテンポで再生し、加速・スキップ・無効化ができる |
| **Godot ネイティブ** | Resource、Scene、Signal、Theme、Tween、Translation、ConfigFile などの組み込み機能を使い、車輪の再発明をしない |
| **一方向の依存** | 上位層は下位層に依存できるが、下位層は上位層の存在を知らない |

---

## 2. レイヤー概観

```
┌─────────────────────────────────────────────────────────────────────┐
│ ⑤ Presentation   scenes/ + src/presentation/                         │
│    Main（ScreenHost / ModalHost / TopBar）· 各 Screen · CombatScreen  │
│    View（表示のみ）· Presenter（イベント再生）· Input ステートマシン（コマンド発行）│
├─────────────────────────────────────────────────────────────────────┤
│ ④ Flow           src/flow/                                           │
│    RunController（ラン進行のステートマシン）· CombatController（戦闘のファサード）│
│    NodeHandler（マップノードの種類ごとに 1 つの Strategy）               │
├─────────────────────────────────────────────────────────────────────┤
│ ③ Domain         src/domain/                                         │
│    RunState · Combat（エンジン）· Combatant · Card · Piles · ActionQueue │
│    MapGenerator · LootTable · ShopFactory · RngStreams · Serializer   │
├─────────────────────────────────────────────────────────────────────┤
│ ② Content        src/content/ + content/*.tres                        │
│    CardData · StatusData · RelicData · PotionData · EnemyData ...     │
│    CardEffect · ValueSource · Condition · TargetRule · CombatBehavior │
├─────────────────────────────────────────────────────────────────────┤
│ ① Platform       src/platform/（Autoload）                            │
│    Content · SaveManager · Settings · Audio · TimeFx · Fx · Log       │
└─────────────────────────────────────────────────────────────────────┘
依存方向：⑤ → ④ → ③ → ②。① は ④⑤ から使われる。③② は ① に依存しない（引数で注入する）
```

| 層 | 基底型 | SceneTree / Node を使えるか | `await` できるか | ファイルに触れるか |
|---|---|---|---|---|
| ② Content | `Resource` | いいえ | いいえ | いいえ（① が読み込む） |
| ③ Domain | `RefCounted` | **いいえ** | **いいえ** | いいえ |
| ④ Flow | `RefCounted` | いいえ | いいえ | いいえ（① に signal を送る） |
| ⑤ Presentation | `Node` / `Control` | はい | はい（アニメーション専用） | いいえ |
| ① Platform | `Node`（Autoload） | はい | はい | **この層だけが可** |

**Domain / Flow に Node を使わない理由**：Node は SceneTree に載って初めて完全なライフサイクルを持つため、テストやシミュレーションのたびにシーンを開く必要が出る。また Node の `_process` は、ルールがこっそりフレーム時間に依存する誘因になる。`RefCounted` は自動で解放され、`new()` でき、`signal` も宣言できるので十分である。

---

## 3. ディレクトリ構成

```
res://
├─ project.godot
├─ addons/
│  ├─ gut/                              テストフレームワーク
│  └─ trycard_tools/                    自前のエディタプラグイン（コンテンツインデックス、検証、カードプレビュー）
├─ assets/
│  ├─ fonts/  textures/{card_frames,card_art,characters,backgrounds,icons}/
│  ├─ models/{characters,weapons,animations}/   3D の戦闘キャラ（KayKit、CC0。§14.6）
│  ├─ audio/{sfx,music}/  shaders/  particles/
├─ content/                             ← すべてのゲームコンテンツ（.tres）、種類別フォルダ
│  ├─ cards/{starter,common,uncommon,rare,special,status,curse}/
│  ├─ statuses/  keywords/  relics/  potions/
│  ├─ enemies/  encounters/  events/  acts/  backdrops/
│  ├─ presets/                          再利用するブロックのインスタンス（例：「選択した対象へ」の TargetRule）
│  ├─ balance/run_config.tres           開始時の数値、報酬 / ショップ / マップのパラメータ
│  └─ content_library.tres              コンテンツインデックス（ツールが自動生成）
├─ localization/
│  ├─ ui.csv                            UI 文字列（key, zh_CN, en）
│  └─ content.csv                       コンテンツ文字列（ツールが .tres から自動書き出し）
├─ src/
│  ├─ platform/                         ① Autoload スクリプト
│  ├─ content/                          ② Resource クラス定義
│  │  ├─ data/        card_data.gd  status_data.gd  relic_data.gd  potion_data.gd
│  │  │               enemy_data.gd  enemy_move.gd  encounter_data.gd  event_data.gd
│  │  │               event_option.gd  act_data.gd  keyword_data.gd  backdrop_data.gd
│  │  │               run_config.gd  content_library.gd
│  │  ├─ effects/     card_effect.gd + impl/（damage、block、apply_status …、repeat、branch …）
│  │  ├─ values/      value_source.gd + impl/（fixed、per_status、per_pile_size …）
│  │  ├─ conditions/  condition.gd + impl/（hp_below、has_status、last_card_type …、all_of、not）
│  │  ├─ targeting/   target_rule.gd + impl/（chosen、self、all_enemies、random_enemy、previous …）
│  │  ├─ behaviors/   combat_behavior.gd + impl/（strength、vulnerable、poison、grant_on_battle_start …）
│  │  ├─ ai/          enemy_ai.gd + impl/（scripted_ai.gd、guardian_ai.gd）
│  │  └─ run_effects/ run_effect.gd + impl/（gold、hp、add_card、remove_card、start_battle、branch …）
│  ├─ domain/                           ③ ルール
│  │  ├─ combat/      combat.gd  combatant.gd  status_set.gd  card.gd  piles.gd
│  │  │               action_queue.gd  actions/  effect_context.gd  damage_calc.gd
│  │  │               behavior_host.gd  hook.gd  combat_event.gd  intent.gd  enemy_mind.gd
│  │  │               card_choice.gd  preview.gd  play_result.gd
│  │  ├─ run/         run_state.gd  deck.gd  relic_slot.gd  potion_belt.gd  reward.gd
│  │  │               shop_stock.gd  shop_factory.gd  loot_table.gd  run_effect_context.gd
│  │  ├─ map/         map_graph.gd  map_node.gd  map_generator.gd
│  │  ├─ rng/         rng_streams.gd
│  │  ├─ text/        card_text.gd（動的テキスト） keyword_scan.gd（効果ツリーの走査）
│  │  └─ save/        run_serializer.gd  save_migrations.gd
│  ├─ flow/                             ④ フロー
│  │  ├─ run_controller.gd  run_phase.gd  combat_controller.gd
│  │  └─ node_handlers/  battle_node.gd  elite_node.gd  boss_node.gd  shop_node.gd
│  │                     event_node.gd  rest_node.gd  treasure_node.gd
│  └─ presentation/                     ⑤ scenes/ に対応するスクリプト
├─ scenes/
│  ├─ main/main.tscn                    メインシーン
│  ├─ screens/  main_menu  map  combat  reward  shop  event  rest  act_transition  run_end
│  ├─ combat/   combat_field  unit_view  intent_view  status_bar  hand_view  card_view
│  │            energy_orb  pile_button  potion_bar  end_turn_button  target_arrow  combat_log
│  ├─ widgets/  top_bar  card_grid  card_picker_modal  pile_viewer_modal  confirm_modal
│  │            relic_icon  potion_icon  tooltip_panel  styled_button
│  ├─ fx/       floating_number  card_fly  card_dissolve  pile_burst  shield_ring  heal_motes
│  │            hit_flash  turn_banner  screen_flash
│  └─ debug/    combat_sandbox.tscn  debug_overlay.tscn
├─ ui/theme/    main_theme.tres（Theme）+ styleboxes/*.tres
├─ tests/
│  ├─ unit/{content,combat,run,map,save,text,architecture,presentation}/
│  ├─ sim/                              自動対戦 / 自動ラン
│  └─ support/                          テスト用の小さなコンテンツ（fixtures）とビルダー（builders）、門番の検査器
└─ tools/                               run_tests.ps1、seed_content.gd などの開発用スクリプト
```

---

## 4. Autoload（グローバルサービス）

意図的に**少なく**保つ。ルール層（②③④）はどの Autoload も呼び出さない。必要なものは引数で渡すので、テストで差し替えができる。

| 名前 | スクリプト | 責務 |
|---|---|---|
| `Content` | `platform/content_service.gd` | `content_library.tres` を読み込み、`card(id)`、`cards_by_rarity()` などの検索を提供する。`ContentLibrary` オブジェクトを Flow 層に渡す |
| `SaveManager` | `platform/save_manager.gd` | ランのセーブ / メタファイルの読み書き（JSON、アトミック書き込み、バージョン移行） |
| `Settings` | `platform/settings.gd` | `ConfigFile` で `user://settings.cfg` に保存。手触り、音量、言語、ウィンドウ。`changed` signal |
| `Audio` | `platform/audio.gd` | 効果音の再生プール、Bus の音量、音楽。プロシージャル合成のフォールバック |
| `TimeFx` | `platform/time_fx.gd` | ヒットストップ / スローモーション（`Engine.time_scale`）。実時間で計測し、必ず元に戻す |
| `Fx` | `platform/fx.gd` | エフェクトシーンのオブジェクトプール：`Fx.spawn(&"floating_number", pos, args)` |
| `Log` | `platform/log.gd` | カテゴリ別ログ（combat / run / save）。デバッグオーバーレイで閲覧できる |

`Main` シーン（Autoload ではない）が `RunController` を保持し、画面の切り替えを担当する。

---

## 5. コンテンツ層：Resource 駆動のデータ

### 5.1 原則

- コンテンツの種類ごとに `class_name` 付きの `Resource` サブクラスを用意し、`.tres` として保存する。コンテンツ間の参照は**Resource を直接参照する**（例：`upgraded: CardData`）。読み込みと依存関係は Godot が処理する。
- すべてのコンテンツは `id: StringName`（全体で一意かつ不変）を持つ。セーブには id だけを保存する。
- **コンテンツ Resource は実行時には読み取り専用**。可変な状態はすべて Domain の実行時オブジェクト（`Card`、`StatusStack`、`RelicSlot`……）に置く。共有された Resource に書き込むと全利用者が汚染されるため、テストとバリデータで監視する（§17.3）。
- `@export_group` / `@export_enum` / `@export_range` で Inspector を編集しやすくし、`_validate_property()` で関係のないフィールドを隠す。

### 5.2 主な Resource

```gdscript
# src/content/data/card_data.gd
class_name CardData extends Resource

enum Type { ATTACK, SKILL, POWER, STATUS, CURSE }
enum Rarity { STARTER, COMMON, UNCOMMON, RARE, SPECIAL }
enum CostMode { FIXED, X, UNPLAYABLE }
enum Keyword { EXHAUST = 1, RETAIN = 2, INNATE = 4, ETHEREAL = 8 }   # ビットフラグ
enum Aim { NONE, ENEMY }            # プレイ時にプレイヤーが敵を 1 体選ぶ必要があるか

@export var id: StringName
@export var art: Texture2D
@export_group("Rules")
@export var type: Type
@export var rarity: Rarity = Rarity.COMMON
@export var cost_mode: CostMode = CostMode.FIXED
@export_range(0, 9) var cost: int = 1
@export var aim: Aim = Aim.NONE
@export_flags("Exhaust", "Retain", "Innate", "Ethereal") var keywords: int = 0
@export var upgraded: CardData                 # アップグレード = 別の CardData に差し替える
@export_group("Effects")
@export var on_play: Array[CardEffect] = []
@export var on_draw: Array[CardEffect] = []
@export var on_discard: Array[CardEffect] = []  # 「手札から捨てられた」ときだけ発動
@export var on_exhaust: Array[CardEffect] = []
@export var end_of_turn_in_hand: Array[CardEffect] = []
@export_group("Text")
@export_multiline var text: String              # 例："{damage} ダメージを与え、脆弱 {vuln} を付与する。"

func name_key() -> StringName: return StringName("CARD_%s_NAME" % String(id).to_upper())
func text_key() -> StringName: return StringName("CARD_%s_TEXT" % String(id).to_upper())
```

| Resource | 主なフィールド |
|---|---|
| `StatusData` | `id`、`icon`、`polarity`（BUFF/DEBUFF/NEUTRAL）、`decay`（NONE/LOSE_ONE_AT_TURN_END/CLEAR_AT_TURN_END/CLEAR_AT_TURN_START）、`max_stacks`、`behaviors: Array[CombatBehavior]`、`text`（`{stacks}` プレースホルダ） |
| `RelicData` | `id`、`icon`、`rarity`、`shop_price`、`behaviors: Array[CombatBehavior]`、`text` |
| `PotionData` | `id`、`icon`、`rarity`、`aim`、`effects: Array[CardEffect]`、`shop_price`、`text` |
| `KeywordData` | `keyword`（ビット）、`text`（ホバー時の説明） |
| `EnemyData` | `id`、`art`、`hp_min`/`hp_max`、`rank`（NORMAL/ELITE/BOSS）、`starting_statuses: Dictionary[StatusData, int]`、`moves: Array[EnemyMove]`、`ai: EnemyAI` |
| `EnemyMove` | `id`、`intent`、`effects`、`weight`、`bonus_weight` + `bonus_when: Condition`、`usable_when: Condition`、`max_in_a_row`、`cooldown`、`max_uses`、`phases`（ビット）、`priority` + `forced_when: Condition` |
| `EncounterData` | `id`、`rank`、`enemies: Array[EnemyData]`、`early`（序盤の行にも出る）、`acts`（ビット、出現可能なアクト）、`backdrop` |
| `EventData` | `id`、`art`、`min_row`、`acts`、`options: Array[EventOption]` |
| `EventOption` | `requires: RunCondition`、`disabled_hint`、`effects: Array[RunEffect]`、`result_text` |
| `ActData` | `id`、`rows`/`columns`/`paths`、`bosses: Array[EncounterData]`、`backdrop` |
| `BackdropData` | `texture`、`tint`、`base_color`、`darken`、`vignette`、`anchor_y` |
| `RunConfig` | 開始時の HP / ゴールド / エネルギー / ドロー / ポーション枠、初期デッキとレリック、報酬ゴールドの範囲、レアリティの重み、ドロップ率、ショップの価格表、マップの重み……（**バランス数値はすべてこの 1 ファイルに集約**） |
| `ContentLibrary` | 種類ごとに 1 つの `Array[...]`。ツールが自動生成する（§17.2） |

### 5.3 カードテキストのプレースホルダ

テキストテンプレートは「N 番目の効果」ではなく**名前付きプレースホルダ**（`{damage}`、`{block}`、`{stacks}`）を使う。効果の順番を入れ替えてもテキストがずれない。各効果は `@export var label: StringName` を持ち、`CardText` が `{label}` をその効果のリアルタイムの数値に置き換える（§6.6）。

---

## 6. 効果ブロック：Strategy + Composite

コンテンツは 4 種類のブロックで構成する。すべて `Resource` のサブクラスで、Inspector の「新規 XXX」からサブタイプを直接選び、入れ子に組み合わせられる。

| ブロック | 基底クラス | 答える問い | パターン |
|---|---|---|---|
| 効果 | `CardEffect` | 何をする？ | Strategy + Composite（コンビネータ） |
| 値の出所 | `ValueSource` | いくつ？ | Strategy（「巨大な enum + switch」の代わり） |
| 条件 | `Condition` | 成立するか？ | Specification（`AllOf` / `AnyOf` / `Not` で組み合わせ可能） |
| 対象ルール | `TargetRule` | 誰に？ | Strategy |

### 6.1 効果

```gdscript
# src/content/effects/card_effect.gd
@abstract class_name CardEffect extends Resource
## ステートレス：同じインスタンスがすべてのカードで共有されるため、apply() でメンバ変数に書き込んではならない。

@export var label: StringName                 # カードテキストのプレースホルダ名
@export var target: TargetRule                # null = 直前の効果の対象を引き継ぐ / 対象なし

## 実行する。戦闘への変更はすべて ctx.combat の API を通し、データを直接書き換えない。
@abstract func apply(ctx: EffectContext) -> void

## 実行可能か（false だとカード全体がプレイ不可になる。コンビネータは必ず true を返す）。
func can_apply(_ctx: EffectContext) -> bool: return true

## プレビュー：カード面の数値と敵のインテントを埋める。状態を一切変更せず、乱数も消費しない。
func preview(_ctx: EffectContext, _out: Preview) -> void: pass

## ツールが効果ツリーを走査するため（キーワード / ステータスのツールチップ、検証）。コンビネータは子効果を返す。
func children() -> Array[CardEffect]: return []
```

> GDScript は Godot 4.5 から `@abstract` に対応している。使用するバージョンが未対応なら、基底クラスのメソッド内で `assert(false, "abstract")` にする。

**原子効果**（`effects/impl/`）：`DamageEffect`（amount: ValueSource、hits: ValueSource、kind、pierce_block）、`BlockEffect`、`ApplyStatusEffect`、`HealEffect`、`LoseHpEffect`、`GainEnergyEffect`、`DrawEffect`、`CreateCardEffect`（card、pile、count、temporary、upgraded、copy_source）、`DiscardEffect`、`ExhaustEffect`、`ChooseCardsEffect`（元の山、枚数、処理、少なく選んでよいか、キャンセル可能か、案内文）、`ModifyCostEffect`、`GrowCardEffect`、`ConsumeStatusEffect`、`SpreadStatusEffect`。

**コンビネータ**（Composite）：`SequenceEffect`、`RepeatEffect`（times: ValueSource）、`BranchEffect`（when: Condition、then、otherwise）、`RandomChoiceEffect`（重み付きの選択肢）、`DeferEffect`（タイミング：このターンの終了時 / 次のターンの開始時）。

### 6.2 値の出所

```gdscript
@abstract class_name ValueSource extends Resource
@export var min_value: int = -999999
@export var max_value: int = 999999
func evaluate(ctx: EffectContext) -> int:
    return clampi(_raw(ctx), min_value, max_value)
@abstract func _raw(ctx: EffectContext) -> int
```

サブクラス：`Fixed(value)`、`Scaled(base, per, unit: ValueSource)`（`base + per × unit`。ほぼすべての動的な値はこれの組み合わせ）、`StatusStacks(status, on: SELF|TARGET)`、`PileSize(pile)`、`HandCount(type_filter)`、`PlayedThisTurn(type_filter)`、`AliveEnemies`、`Block(on)`、`Hp(on)`、`MissingHp(on)`、`XValue`、`RepeatIndex`、`ResolveStat(stat: DAMAGE_DEALT | LAST_DAMAGE | CARDS_AFFECTED | CONSUMED_STACKS | KILLS)`、`CardGrowth`、`CardRetainedTurns`、`TurnNumber`、`CurrentEnergy`。

手間を省くため、よく使う `Fixed` は Inspector で直接入力できるようにする。効果のフィールドの型は `ValueSource` のまま、`@tool` の `EditorInspectorPlugin` で「整数」をワンクリックで `Fixed` に変換する（§17.4）。

### 6.3 条件

```gdscript
@abstract class_name Condition extends Resource
@export var negate: bool = false
func test(ctx: EffectContext, subject: Combatant = null) -> bool:
    return _test(ctx, subject) != negate
@abstract func _test(ctx: EffectContext, subject: Combatant) -> bool
```

サブクラス：`HpBelowPercent(on, percent)`、`HpAtMost`、`HasStatus(on, status)`、`BlockAtLeast(on, value)`、`Compare(left: ValueSource, op, right: ValueSource)`（汎用の比較。「手札が N 枚以上」「このターンのプレイ数が N 以上」「山の枚数が N 以上」「エネルギーが N 以上」「ターン数が N 以上」など、多数の条件をこれ 1 つでまかなう）、`LastCardType(type)`、`HandHasType(type_filter)`、`IsFirstTurn`、`KilledThisResolve`、`AllOf`、`AnyOf`。

`Compare` のおかげで、「数のしきい値」系の条件をそれぞれ別クラスにする必要がない。

### 6.4 対象ルール

`ChosenTarget`、`Self`、`AllEnemies`、`AllAllies`、`Everyone`、`RandomEnemies(count, allow_repeat)`、`LowestHpEnemy`、`HighestHpEnemy`、`PreviousTargets`。共通のフィルタ：`exclude_self`、`require: Condition`。プレビューモードでは `RandomEnemies` は常に先頭を取り、乱数を消費しない。

### 6.5 EffectContext（1 回の解決の現場）

```gdscript
class_name EffectContext extends RefCounted
var combat: Combat
var source: Combatant            # 発動者
var chosen: Combatant            # プレイヤーが選んだ対象
var card: Card                   # 元のカード（ポーション / 敵の行動では null）
var x: int                       # X コストで実際に支払った量
var repeat_index: int
var targets: Array[Combatant]    # 現在の効果で解決された対象
var previous_targets: Array[Combatant]
var stats: ResolveStats          # 今回の解決の統計（ダメージ、撃破、影響枚数、消費スタック数）。カード 1 枚で共有
var preview: bool                # true = プレビュー。一切の変更と乱数を禁止
var depth: int                   # コンビネータの入れ子の深さ（上限 8）

func child() -> EffectContext    # コンビネータ用：現場を複製し depth + 1、stats は共有
```

### 6.6 カードの動的テキスト

`CardText.render(card, ctx) -> String`：`preview = true` の現場で、`label` を持つ各効果の `preview()` を呼んでリアルタイムの数値を得る。基本値と比べて BBCode で色付けする（基本値より高い = 緑、低い = 赤）。ステータス名 / キーワードは `[url=status:poison]毒[/url]` で囲んでホバーできるようにする。カードテキストを表示するすべての場所（手札、報酬、ショップ、デッキ）でこの関数 1 つを使う。

---

## 7. 戦闘エンジン

### 7.1 中心となる考え方

1. **アクションキュー（Action Queue）**：戦闘を変化させる動作はすべて、キューに積まれる `CombatAction`（Command パターン）である。エンジンはキューが空になるか「プレイヤーの入力が必要」なアクションに当たるまで、取り出しては実行を繰り返す。
   - `push_top()`：子効果やコンビネータの展開。すぐ続けて実行される。
   - `push_bottom()`：トリガー（死亡、捨て札、廃棄、トゲの反撃）。今の一連の処理が終わってから実行されるため、**本質的に再帰しない**。
2. **ルールは同期、表現は非同期**：エンジンは一気に最後まで実行し、起きたことを `CombatEvent` ログに書き込む（同時に `event_emitted` signal を出す）。表現層は自分のテンポで再生する。
3. **ファサード（Facade）**：外部は `CombatController` の少数のメソッドを通じてのみ戦闘を操作する。

### 7.2 クラスの関係

```
CombatController（④ ファサード：UI / テスト / AI ボットはこれだけを呼ぶ）
   └─ Combat（③ エンジン）
        ├─ player: Combatant ─┬─ statuses: StatusSet ─ StatusStack(data, stacks)
        ├─ enemies: Array[Combatant]  └─ mind: EnemyMind（敵のみ）
        ├─ piles: Piles（draw / hand / discard / exhaust）
        ├─ relics: Array[RelicSlot]（RunState から）
        ├─ queue: ActionQueue
        ├─ hooks: HookDispatcher（Behavior の収集、安定ソート、ディスパッチ）
        ├─ deferred: Dictionary[Timing, Array]（遅延効果）
        ├─ rng: RngStreams（RunState と共有）
        ├─ turn: TurnState（ターン数、エネルギー、このターンのプレイ統計、直前のカード種別）
        ├─ pending_choice: CardChoice（null 以外 = プレイヤーのカード選択待ち）
        └─ events: Array[CombatEvent]（+ signal event_emitted）
```

### 7.3 CombatController（ファサード）

```gdscript
class_name CombatController extends RefCounted

signal finished(victory: bool)

var combat: Combat

# —— コマンド（唯一の書き込み口）——
func play_card(card: Card, target: Combatant = null) -> PlayResult
func use_potion(slot: int, target: Combatant = null) -> PlayResult
func discard_potion(slot: int) -> void
func submit_choice(cards: Array[Card]) -> void   # pending_choice への回答
func end_turn() -> void

# —— クエリ（純粋関数。毎フレーム呼んでよい）——
func check_card(card: Card, target: Combatant = null) -> PlayResult  # ok + 理由
func needs_target(card: Card) -> bool
func card_text(card: Card, target: Combatant = null) -> String
func intent_of(enemy: Combatant) -> Intent
func pending_choice() -> CardChoice
func is_over() -> bool
```

`PlayResult` は `ok: bool` と `reason`（NOT_YOUR_TURN / NOT_IN_HAND / NOT_ENOUGH_ENERGY / UNPLAYABLE / NEED_TARGET / INVALID_TARGET / BLOCKED_BY_EFFECT / WAITING_FOR_CHOICE / COMBAT_OVER）を持つ。

### 7.4 ActionQueue

```gdscript
class_name ActionQueue extends RefCounted

enum Step { DONE, WAIT }        # WAIT = プレイヤーの入力が必要。エンジンは一時停止する

var _items: Array[CombatAction] = []
var _running := false

func push_top(a: CombatAction) -> void: _items.push_front(a)
func push_top_many(list: Array[CombatAction]) -> void   # 逆順に push_front し、元の順序で実行されるようにする
func push_bottom(a: CombatAction) -> void: _items.push_back(a)

## 空になるか WAIT に当たるまで実行する。再入安全。無限ループ防止のステップ上限あり。
func run(combat: Combat) -> void:
    if _running: return
    _running = true
    var guard := 0
    while not _items.is_empty() and not combat.is_over():
        guard += 1
        assert(guard < 10000, "ActionQueue runaway")
        var a: CombatAction = _items.pop_front()
        if a.execute(combat) == Step.WAIT:
            _items.push_front(a)        # 戻しておき、submit_choice の後に続行する
            break
    _running = false
```

`CombatAction`（基底クラス、`execute(combat) -> Step`）の実装はごく少数で、「スケジューリング」だけを担う。本当のルールは効果と `Combat` の API にある。

| Action | 役割 |
|---|---|
| `ResolveEffectAction(effect, ctx)` | 対象を解決 → `can_apply` → `apply`。コンビネータは `apply` の中で子効果を Action に包んで `push_top` する |
| `CallAction(callable)` | 後処理のロジックを包む（例：プレイ終了後にカードを行き先へ送る） |
| `ChooseCardsAction(choice)` | プレイヤーのターン + 人間が操作中 → `pending_choice` を設定して WAIT を返す。そうでなければ `AutoChooser` で即答する |
| `DeathAction(unit)` | 死亡処理、断末魔効果 |
| `TriggerCardAction(card, effects)` | カードのドロー時 / 捨てられた時 / 廃棄された時のトリガー |

**この設計の利点**：一時停止（カード選択待ち）は「キューが止まる」だけ、再開は「もう一度 `run()` する」だけ。コルーチンも `await` も要らず、「一時停止中に後続の処理が先に走ってしまう」問題も起きない。セーブ時のエンジンの状態も明快である。

### 7.5 カードプレイの流れ

```gdscript
func play_card(card: Card, target: Combatant) -> PlayResult:
    var r := check_card(card, target)
    if not r.ok: return r
    var plays := 1 + combat.hooks.extra_plays(card)          # エコー。上限 8
    if combat.hooks.cancel_play(card): return PlayResult.fail(&"BLOCKED_BY_EFFECT")
    var spent := combat.spend_energy_for(card)              # X コストは全部使う
    combat.piles.take_from_hand(card)                        # 先に手札から外し、「手札をすべて捨てる」に自分が含まれないようにする
    combat.turn.on_card_played(card)
    combat.emit(CombatEvent.card_played(card, target))
    combat.hooks.notify_card_played(card)
    var stats := ResolveStats.new()
    # 順に積む：各回の解決 → 後処理
    var actions: Array[CombatAction] = []
    for i in plays:
        var ctx := combat.make_context(combat.player, target, card, spent, stats)
        actions.append_array(ActionFactory.for_effects(card.data.on_play, ctx))
    actions.append(CallAction.new(combat.finish_play.bind(card, stats)))
    combat.queue.push_top_many(actions)
    combat.queue.run(combat)
    return PlayResult.success()
```

`finish_play`：行き先を決める（パワーは戦闘から除外。廃棄または一時カード → 廃棄札。それ以外 → 捨て札。Behavior で書き換え可能）→「直前のカード種別」を更新 → `notify_card_resolved` → 勝敗判定。

### 7.6 ターンの流れ

`Combat.begin_player_turn()` と `Combat.end_player_turn()` は、`GameDesign.md` §5.2 / §5.4 の手順を Action として順に積み、トリガーの順序を固定かつテスト可能にする。敵のターン `run_enemy_turn()`：各敵が「ブロックを消す → インテントを実行（複数の `ResolveEffectAction`）→ トリガーを処理」し、全員終わったらプレイヤーのターン開始に戻る。

### 7.7 ダメージと数値のパイプライン

```gdscript
class_name DamageCalc extends RefCounted   # 1 回のダメージの変更可能なデータ（struct + ref の代わり）
var amount: int
var kind: int            # ATTACK / STATUS / THORNS / HP_LOSS
var pierce_block: bool
var source: Combatant
var target: Combatant
var lethal_prevented: bool
```

`Combat.deal_damage(calc)` が**唯一の**ダメージの入り口：

```
hooks.modify(OUTGOING_DAMAGE, calc)   # 筋力（+）、弱体（×0.75）。priority 順
hooks.modify(INCOMING_DAMAGE, calc)   # 脆弱（×1.5）
ブロックを減らす（pierce_block ならスキップ） → emit(BLOCKED)
hooks.modify(LETHAL, calc)            # 起死回生：HP 1 で踏みとどまる
HP を減らす → emit(DAMAGED, flags: LETHAL / OVERKILL)
hooks.notify(DAMAGED, calc)           # トゲ：push_bottom で反撃（ATTACK のみ反撃）
死亡したら → push_bottom(DeathAction)
```

`Combat.preview_damage(source, target, base) -> int` は同じ補正パイプラインを通すが HP は減らさない。**カード面の数字もインテントの数字もここから得る**ので、表示 == 実際が保証される。

同じ「変更可能なデータ + パイプライン」を次にも使う：`BlockCalc`（ブロック獲得）、`HealCalc`、`StatusApplyCalc`（アーティファクトはここで打ち消す）、`EnergyCalc`、`DrawCalc`、`CostCalc`（カードのコスト）。

### 7.8 カードと山

```gdscript
class_name Card extends RefCounted          # ラン中の 1 枚のカード
var uid: int
var data: CardData                           # アップグレード = data を差し替える
var upgrades: int
var temporary: bool                          # 戦闘中に生成され、戦闘終了で消える
var mods: CardMods                           # 戦闘中の一時的な数値：cost_delta_combat / cost_delta_turn /
                                             # growth / retained_turns / extra_keywords / retain_this_turn
func has_keyword(k: int) -> bool
func reset_combat_mods() -> void
```

`Piles`：`draw / hand / discard / exhaust`（`Array[Card]`、山の一番上 = 配列の末尾）、手札上限 10。`draw_one()`（空なら捨て札を自動でシャッフル、手札がいっぱいなら捨て札へ）、`discard_from_hand()`（on_discard を発動）、`exhaust()`（必ず on_exhaust を発動し、廃棄札に入った**後で**発動）、`end_turn_cleanup()`（エセリアル / 保留 / 捨てる）。トリガーはすべて `push_bottom`。

`Deck`（ラン）と `Piles`（戦闘）は別物。開戦時に `Deck` の `Card` オブジェクトを山札にコピーし、戦闘終了時に `mods` をクリアして一時カードを破棄する。

### 7.9 イベントログ

```gdscript
class_name CombatEvent extends RefCounted
enum Kind { COMBAT_STARTED, TURN_STARTED, TURN_ENDED, ENEMY_TURN_STARTED,
            CARD_DRAWN, CARD_PLAYED, CARD_DISCARDED, CARD_EXHAUSTED, CARD_CREATED, CARD_RETAINED,
            PILE_SHUFFLED, CHOICE_REQUESTED,
            DAMAGED, BLOCKED, HEALED, BLOCK_GAINED, BLOCK_CLEARED,
            STATUS_APPLIED, STATUS_REMOVED, STATUS_TRIGGERED,
            ENERGY_CHANGED, INTENT_CHANGED, POTION_USED, POTION_DISCARDED,
            RELIC_TRIGGERED, UNIT_DIED, COMBAT_ENDED }
var kind: Kind
var source_uid: int
var target_uid: int
var value: int
var id: StringName          # カード / ステータス / レリックの id
var flags: int              # LETHAL / OVERKILL / …（ルール層がその場で決める。表現層は推測しない）
var snapshot: Dictionary    # 表現に必要な「その時点の値」（例：被ダメージ後の残り HP）。再生時にモデルを見返さずに済む
```

- ルール層は**書くだけで読まない**。イベントを 1 つ出すたびに `Combat.version` を +1 し、UI はそれを見て派生データ（インテントの数字、カードテキスト）を再計算するか決める。
- `snapshot` のおかげで、表現層は再生時にモデルの最終値ではなく「イベント発生時」の値を表示できる。HP バーが一段ずつ減っていくのはこのためである。

### 7.10 プレイヤーのカード選択

`CardChoice`：候補 `Array[Card]`、`min`/`max`、処理（DISCARD / EXHAUST / RETAIN / DUPLICATE / TO_DRAW_TOP / TO_DRAW_BOTTOM / TO_HAND / TO_DISCARD）、`cancellable`、`prompt`。`submit_choice()` は候補内のカードだけを受け付け、処理を実行 → 影響枚数を `stats` に書く → `queue.run()` で続行する。

`Combat.chooser`：`null` = 人間（一時停止して待つ）。テスト / ボット / 敵のターンでは `AutoChooser`（`card_effect` 乱数ストリームを使用）を使い、決して詰まらない。

---

## 8. 補正とトリガー：Behavior パイプライン

### 8.1 統一モデル

ステータスとレリックはどちらも「ユニットに付き、いくつかの `CombatBehavior` を持つもの」で、違いは、ステータスはスタック数を持ち減衰する、レリックは消えずカウンタを持つ、という点だけ。どちらも `BehaviorHost` インターフェース（`owner`、`stacks`、`counter`、`data`）を実装し、Behavior はスタック数 / カウンタを host から読む。**Behavior 自身は状態を持たない**。

```gdscript
# src/content/behaviors/combat_behavior.gd
@abstract class_name CombatBehavior extends Resource
## ステートレス。スタック数・カウンタは host から取得し、カウントが必要なら host.counter に書く。

enum Hook {
    TURN_START = 1 << 0, TURN_END = 1 << 1, COMBAT_START = 1 << 2, COMBAT_END = 1 << 3,
    CARD_PLAYED = 1 << 4, CARD_DRAWN = 1 << 5, CARD_DISCARDED = 1 << 6, CARD_RESOLVED = 1 << 7,
    OUTGOING_DAMAGE = 1 << 8, INCOMING_DAMAGE = 1 << 9, DAMAGED = 1 << 10, LETHAL = 1 << 11,
    BLOCK_GAIN = 1 << 12, BLOCK_CLEAR = 1 << 13, HEAL = 1 << 14, STATUS_APPLY = 1 << 15,
    STATUS_APPLIED = 1 << 16, DEATH = 1 << 17, CARD_COST = 1 << 18, CARD_DESTINATION = 1 << 19,
    PLAY_COUNT = 1 << 20, TURN_ENERGY = 1 << 21, TURN_DRAW = 1 << 22,
}
enum Priority { EARLY = -100, ADD = 0, MULTIPLY = 100, CLAMP = 200 }

func hooks() -> int: return 0          # サブクラスは自分が購読する Hook を（ビットで）返す
func priority() -> int: return Priority.ADD

# —— 通知型（戻り値なし）——
func on_event(_hook: Hook, _host: BehaviorHost, _combat: Combat, _payload) -> void: pass
# —— 補正型（calc オブジェクトを書き換える）——
func modify(_hook: Hook, _host: BehaviorHost, _combat: Combat, _calc) -> void: pass
```

### 8.2 HookDispatcher

```gdscript
class_name HookDispatcher extends RefCounted
func notify(hook: int, payload = null) -> void
func modify(hook: int, calc) -> void
## 収集：生存している全ユニットのステータス + プレイヤーのレリックのうち、hooks() にそのビットを含む Behavior を
## priority で**安定ソート**する（自前の挿入ソート。Array.sort_custom は安定ではない）。
func _collect(hook: int, include_dead := false) -> Array[HookEntry]
```

- **プル型**：必要なときにその場で収集し、購読 / 解除は行わない。ステータスが消えればその Behavior も自然に効かなくなる。ステータス / レリックを追加してもエンジンを 1 行も変える必要がない。
- 性能：1 戦闘のユニットは 6 以下、ステータスは数十程度なので、その場での収集で十分速い。プロファイリングでホットスポットになったら、「Hook ビットごとのキャッシュ + `version` による無効化」を追加する。
- Behavior が「実際に発動した」ときは自分で `combat.emit(RELIC_TRIGGERED)` する。**プレビュー / 補正の経路ではイベントを出さない**（`calc.preview` が true ならスキップ）。

### 8.3 Behavior の実装一覧

| Behavior | Hook | 用途 |
|---|---|---|
| `FlatDamageBonus`（per stack） | OUTGOING_DAMAGE | 筋力 |
| `DamagePercent`（outgoing/incoming, %） | OUTGOING / INCOMING_DAMAGE | 弱体 -25%、脆弱 +50% |
| `DamageOverTime` | TURN_END | 毒 |
| `HealOverTime` | TURN_END | 再生 |
| `KeepBlock` | BLOCK_CLEAR | バリケード |
| `Retaliate` | DAMAGED | トゲ |
| `NegateDebuff` | STATUS_APPLY | アーティファクト |
| `CheatDeath(heal)` | LETHAL | 起死回生 |
| `GrantStatusOnTurnStart(status, per_stack)` | TURN_START | 悪魔化 |
| `GrantStatusOnCombatStart(status, stacks)` | COMBAT_START | 金剛杵、青銅の鱗、アーティファクトトーテム、トカゲの尻尾 |
| `CombatStartResources(block, heal)` | COMBAT_START | 錨、血の小瓶 |
| `VictoryRewards(heal, gold)` | COMBAT_END | 燃える血、道具箱 |
| `TurnResources(energy, draw, first_turn_only)` | TURN_ENERGY / TURN_DRAW | 黒い星、賢者の石、提灯、準備袋 |
| `FirstCardOfTypeCostDown(type, amount)` | CARD_COST + CARD_PLAYED | ペン先 |
| `FirstCardOfTypeEcho(type)` | PLAY_COUNT | 反響の護符 |
| `RedirectCardDestination(type, pile)` | CARD_DESTINATION | リサイクラー |
| `EveryNCardsHeal(type, n, heal)` | CARD_PLAYED | 瞑想の数珠 |

---

## 9. 敵 AI

### 9.1 データと実行時の分離

- `EnemyData.moves`（データ）+ `EnemyData.ai: EnemyAI`（Strategy の Resource、**ステートレス**）。
- `EnemyMind`（実行時、敵ごとに 1 つ）：`history`、`sequence_step`、`phase`、`uses: Dictionary`、`current_move`、`current_intent`。

```gdscript
@abstract class_name EnemyAI extends Resource
func choose_move(mind: EnemyMind, combat: Combat) -> EnemyMove      # デフォルト実装は ScriptedAI を参照
func on_phase_changed(_mind: EnemyMind, _combat: Combat, _phase: int) -> void: pass
```

### 9.2 ScriptedAI（デフォルト。ほぼすべての敵をカバー）

3 段階の決定：
1. **強制**：`priority > 0` かつ `forced_when` が成立し、かつ使用可能 → そのまま選ぶ。
2. **序盤 / 固定シーケンス**：`opening: Array[StringName]`（技の id）。`loop_opening` でループするか決める。シーケンスのステップ数は履歴とは別に数える。
3. **重み付きランダム**：使用不可のもの（phases、`usable_when`、`max_in_a_row`、`cooldown`、`max_uses`）を除外し、重み = `weight + (bonus_when が成立 ? bonus_weight : 0)` で、`enemy_ai` 乱数ストリームから選ぶ。

判定条件はすべて `preview` の現場で実行する（乱数を消費しない）。複数フェーズ：`phase_thresholds: PackedInt32Array`（HP の %）。しきい値をまたいだら `on_phase_changed` を呼ぶ。

### 9.3 カスタム AI の境界線

「技を選ぶ判断ではなく、データで表現できない副作用」の場合だけサブクラスを書く。例：`GuardianAI` は `on_phase_changed`（自身のデバフを解除 + 筋力を得る）だけをオーバーライドし、パラメータは `@export` にして、別の敵でも再利用できるようにする。

### 9.4 インテント

`Intent`：`kind`（ATTACK / ATTACK_DEFEND / ATTACK_DEBUFF / DEFEND / BUFF / DEBUFF / SPECIAL / SLEEP / UNKNOWN）、`damage`、`hits`、`block`、`uncertain`。選ばれた技の効果の `preview()` を集計して作る（`RandomChoiceEffect` は uncertain を立てる、`DeferEffect` は数えない、自分自身へのダメージは攻撃に数えない）。プレイヤーのステータスが変わったら数字だけを再計算し（`Combat.version` が変わったとき）、技は選び直さない。

---

## 10. ラン進行（Run）

### 10.1 RunState（ラン中の可変データのすべて。セーブの唯一の出所）

```gdscript
class_name RunState extends RefCounted
var seed: int
var rng: RngStreams
var hp: int;  var max_hp: int;  var gold: int
var energy_per_turn: int;  var draw_per_turn: int
var deck: Deck                        # Array[Card] + uid の採番器
var relics: Array[RelicSlot]          # 順序 = 発動順
var potions: PotionBelt               # 枠数 + Array[PotionData]
var act_index: int;  var act_count: int
var map: MapGraph;  var node_id: int = -1;  var visited: PackedInt32Array
var phase: RunPhase.Id
var battles_won: int
var pending_reward: Reward            # 生成済みで受け取り待ち
var shops: Dictionary[int, ShopStock] # ショップノードごとに 1 つの在庫（リロール防止）
var removals_bought: int;  var upgrades_bought: int
var queued_encounter: StringName      # イベントが予約した戦闘（読まれたら消える）
var queued_encounter_rewards: bool
var active_encounter: StringName      # 進行中の戦闘（ロード時の再開用）
var interactive: bool                 # 人間がプレイ中か（戦闘中のカード選択で一時停止するかを決める）
```

`RunState` にはデータと単純な不変条件（`change_hp()`、`add_card()`、`add_potion() -> bool`……）だけを置き、**フローの判断はここに置かない**。

### 10.2 RunController：ステートマシン + ノード戦略

```gdscript
class_name RunController extends RefCounted

signal phase_changed(phase: RunPhase.Id)
signal checkpoint_reached(reason: StringName)   # SaveManager が購読する。誰も購読しなければ副作用なし

var state: RunState
var content: ContentLibrary
var config: RunConfig
var combat: CombatController                    # 戦闘中のみ

func start_new(seed: int) -> void
func resume(saved: RunState) -> void
func enter_node(node_id: int) -> void
func acknowledge_combat_end() -> void           # プレイヤーが戦闘終了画面で「続ける」を押した
func take_reward(kind: StringName, index := -1) -> void
func buy(item_index: int) -> bool
func choose_event_option(index: int) -> EventOutcome
func rest_heal() -> void
func rest_upgrade(card: Card) -> void
func leave_node() -> void                       # マップへ戻る唯一の出口
func advance_act() -> void
func abandon() -> void
```

フェーズ（`RunPhase.Id`）：`MAP / COMBAT / REWARD / SHOP / EVENT / REST / TREASURE / ACT_TRANSITION / DEFEAT / VICTORY`。メインメニューは Run のフェーズではない。Run の外側にあり、`Main` が直接管理する。

**マップノードの種類ごとに 1 つの `NodeHandler`（Strategy）** を用意し、`RunController` はノード種別で表を引いてディスパッチする。

```gdscript
@abstract class_name NodeHandler extends RefCounted
@abstract func phase() -> RunPhase.Id
@abstract func enter(run: RunController, node: MapNode) -> void   # 内容を生成する（ショップ在庫、イベント、戦闘）
func on_resume(run: RunController, node: MapNode) -> void: enter(run, node)  # ロード時に再実行
```

`BattleNode` / `EliteNode` / `BossNode` / `ShopNode` / `EventNode` / `RestNode` / `TreasureNode`。新しいノード種別 = Handler 1 つ + 画面シーン 1 つを追加するだけで、`RunController` は変えない。

### 10.3 セーブのチェックポイント（意図的に選んだ 4 か所）

| チェックポイント | 位置 | 理由 |
|---|---|---|
| `node_entered` | `enter_node`：ノード確定後、`handler.enter()` の前 | ロード時に同じ乱数状態で再実行するので、ショップ / 宝箱 / イベントの結果が同じになる |
| `combat_started` | 開戦：シャッフルして初手を引く前 | やり直しても初手が同じ |
| `reward_generated` | 戦闘報酬の生成後 | ロードしても 3 択を引き直せない |
| `returned_to_map` | `leave_node` | ノード内の変更は丸ごと保存されるか、丸ごと破棄される |

### 10.4 ラン側のサービス

| クラス | 責務 |
|---|---|
| `MapGenerator` | 静的関数 `generate(rng, act, content, config) -> MapGraph`。ルールは `GameDesign.md` §4.1。集合から候補を取るときは必ずソートしてから乱数で選ぶ |
| `LootTable` | カードの抽選（レアリティの重み、ボーナス、重複除外、空プールのフォールバック）、レリックの抽選（所持済みを除外）、ポーションの抽選 |
| `RewardFactory` | 戦闘報酬 / 宝箱 |
| `ShopFactory` | ショップの在庫と価格 |
| `RunEffect`（Resource）+ `RunEffectContext` | イベントの効果。プレイヤーのカード選択が必要なら `ctx.requests`（`RunChoiceRequest`）に積み、`EventScreen` が順番に処理する |
| `RunCondition`（Resource） | イベント選択肢の条件（ゴールド ≥、HP < %、レリック / カードの所持、デッキ枚数、アップグレード可能、勝利数……。`AllOf` / `Not` も可） |

`StartBattleEffect` は `state.queued_encounter` に書くだけで、実際の開戦は `leave_node` が消費する。**フローの遷移の出口は RunController だけ**。

---

## 11. 乱数

```gdscript
class_name RngStreams extends RefCounted
const STREAMS: Array[StringName] = [&"map", &"encounter", &"draw", &"combat", &"enemy_ai",
                                    &"reward", &"shop", &"event", &"card_effect", &"potion"]
var _gens: Dictionary[StringName, RandomNumberGenerator] = {}

func _init(seed: int) -> void:
    for s in STREAMS:
        var g := RandomNumberGenerator.new()
        g.seed = hash([seed, s])          # ストリームごとに独立した起点
        _gens[s] = g

func range_int(stream: StringName, lo: int, hi_inclusive: int) -> int
func chance(stream: StringName, percent: int) -> bool
func pick(stream: StringName, items: Array)
func shuffle(stream: StringName, items: Array) -> void   # Fisher–Yates（Array.shuffle はグローバル乱数なので使わない）
func weighted(stream: StringName, weights: PackedInt32Array) -> int
func save() -> Dictionary        # { stream: gen.state }
func restore(d: Dictionary) -> void
```

- Godot の `RandomNumberGenerator`（PCG32）は `state` を読み書きできる。セーブにはシードではなく `state` を保存するので、ロード後に正確に続きから再開できる。
- 各ストリームは独立：戦闘をやり直しても（draw / combat を消費しても）その後の報酬列は変わらない。新しいストリームを追加しても既存のストリームに影響しない。
- ②③④ 層では `randi()`、`randf()`、`Array.shuffle()`、`Array.pick_random()`（すべてグローバル乱数）の使用を**禁止**する。ソースコードを走査するテストで監視する（§18.4）。

---

## 12. セーブ

### 12.1 形式と場所

- `user://saves/run.json`（ランのセーブ）、`run.json.bak`、`user://saves/profile.json`（ランをまたぐデータ。アンロック / 統計など）。設定は別に `user://settings.cfg`（`ConfigFile`）。
- ランのセーブは `.tres` ではなく **JSON** を使う。ユーザーが書き換え可能な Resource ファイルを読み込むと任意のスクリプトが実行される危険があり、また JSON ならコンテンツ Resource の改版とも切り離せる。

### 12.2 Serializer（Memento）

`RunSerializer.to_dict(state) -> Dictionary` / `from_dict(d, content) -> RunState`：
- id と数値だけを保存し、オブジェクト参照は保存しない。アップグレード済みのカードはアップグレード後の `CardData.id` を保存する。
- マップは丸ごと保存する（シードから再生成すると、コンテンツが変わった途端に別のマップになる）。
- 各乱数ストリームの `state`、`deck` の次の uid を保存する。
- 最上位に `version`。`SaveMigrations` は `func(d: Dictionary) -> Dictionary` の列で、バージョンごとに順に移行する。
- テスト：`to_dict → from_dict → to_dict` の 2 回の出力が完全に一致する。

### 12.3 SaveManager

- `RunController.checkpoint_reached` を購読 → シリアライズ → アトミック書き込み（`.tmp` に書く → 旧ファイルを `.bak` にリネーム → `.tmp` を正式名にリネーム）。
- 読み込みに失敗したら自動で `.bak` を試す。両方失敗したら「セーブデータ破損」を報告し、例外は投げない。
- `DEFEAT` / `VICTORY` でランのセーブを削除する。

### 12.4 ロード時の再開

`RunController.resume(state)`：`state.phase` に応じて現場を再構築する。戦闘中 → `active_encounter` で戦闘をやり直す（乱数状態は開戦前のスナップショットなので初手が同じ）。ショップ / イベント / 休憩 / 宝箱 → `handler.on_resume()` で再実行。報酬 → 生成済みの報酬をそのまま表示。

---

## 13. プレゼンテーション層のアーキテクチャ

### 13.1 Main シーン

```
Main (Node)                          main.gd：RunController を保持し、phase に応じて画面を切り替える
├─ Background (CanvasLayer 0)        BackdropView
├─ Screens (CanvasLayer 1)           ScreenHost：同時に 1 つの Screen だけ
├─ TopBar (CanvasLayer 2)            常駐。画面切り替えで作り直さない
├─ Modals (CanvasLayer 5)            ModalHost：スタック式（カード選択、デッキ閲覧、確認ダイアログ）
├─ ScreenFx (CanvasLayer 10)         ターンバナー、被ダメージの赤フラッシュ
└─ Tooltip (CanvasLayer 100)         TooltipPanel、mouse_filter = IGNORE
```

- `ScreenHost.show_screen(scene: PackedScene, args := {})`（`Control.show()` と衝突するため `show` ではない）：旧画面をフェードアウト → `queue_free()` → 新画面をインスタンス化 → `enter(args)` → フェードイン。切り替え時に `ModalHost.clear()` し、ダイアログの取り残しを防ぐ。
- フェーズ → シーンの対応表は `main.tscn` の `@export var screens: Dictionary[RunPhase.Id, PackedScene]` に書く。画面を追加してもコードは変えない。
- `Screen` 基底クラス：`enter(args)`、`exit()`、`@export var show_top_bar := true`。

### 13.2 View / Presenter / Input の分担（MVP）

| 役割 | 責務 | 例 |
|---|---|---|
| **Model** | ルール層のオブジェクト（表現層からは読み取り専用） | `Combat`、`RunState` |
| **View**（シーン） | 「表示」だけを担う。`set_xxx()` / `play_xxx()` メソッドを提供し、ユーザー操作は signal で通知する。**ルールを知らない** | `UnitView.play_hit(amount, severity)`、`CardView.set_card(card, text)`、`signal hovered` |
| **Presenter** | Model のイベントを購読し、「いつ、どんなテンポで」どの View を更新するかを決める | `CombatPresenter`、`TopBarPresenter` |
| **Input** | View の signal を Controller へのコマンドに翻訳する | `HandInput`（ステートマシン）、`MapScreen` のノードクリック → `run.enter_node()` |

Godot の慣例：**下へはメソッド呼び出し、上へは signal（call down, signal up）**。子の View は親への参照を持たず、`get_parent()` で相手を探さない。別の枝同士のやり取りは、共通の上位（Presenter / Screen）が配線する。

### 13.3 シーン構成の原則

- 再利用する視覚部品 1 つ = シーン 1 つ（`card_view.tscn`、`unit_view.tscn`、`relic_icon.tscn`）。
- シーン内のノードは **Unique Name**（`%CostLabel`）でアクセスし、パスをハードコードしない。
- 静的なレイアウトはエディタで組み（コンテナ + アンカー）、動的なリスト（手札、敵、商品、マップノード）はスクリプトで `instantiate()` する。
- 見た目は `ui/theme/main_theme.tres` だけから決める。フォント、ボタンの 4 状態、パネルの `StyleBoxFlat`（角丸、影、枠線）は **Type Variation** で名前を付ける（`PanelCard`、`PanelTooltip`、`ButtonPrimary`、`ButtonDanger`……）。ノード上で色 / 角丸を場当たり的に上書きしない。
- ストレッチ：`canvas_items` + `expand`、基準 1920×1080。

### 13.4 ツールチップ

- 一般的な Control：`_make_custom_tooltip(_text)` をオーバーライドして `tooltip_panel.tscn` のインスタンスを返す（Godot 組み込みの仕組み。遅延と位置決めを自動で処理する）。
- カードや手札など「即座に、複数の用語を、横に並べて」表示したいもの：`CardView` のホバー時に `TooltipPanel` を直接表示する。内容は `KeywordScan.collect(card.data)`（効果ツリーを再帰的に走査して、使われているステータスとキーワードを得る）から作り、**文字列マッチはしない**。
- RichTextLabel の `[url]` 用語（`meta_hover_started`）で、対応するステータスの説明を表示する。

---

## 14. 戦闘画面の詳細

### 14.1 シーンツリー

```
CombatScreen (Screen)                         combat_screen.gd：組み立てと配線
├─ Field (Control)                            揺れるのはこの層だけ
│  ├─ Stage (BattleStage：SubViewportContainer) 3D の舞台。一番下（UnitView の HUD より下）。§14.6
│  ├─ PlayerSlot → UnitView
│  └─ EnemyRow (HBoxContainer) → UnitView × N
├─ Hud
│  ├─ EnergyOrb  ├─ PileButton(draw)  ├─ PileButton(discard)  ├─ PileButton(exhaust)
│  ├─ PotionBar  ├─ EndTurnButton     └─ CombatLog
├─ HandView (Control)                         扇形の配置、ホバー、ドラッグ
├─ TargetArrow (Node2D：Line2D + Polygon2D)
├─ ResultPanel                                戦闘終了 +「続ける」（敗北と sandbox だけ。ラン中の勝利は自動で報酬へ = §19.12）
├─ CombatPresenter (Node)                     イベントの再生
└─ HandInput (Node)                           入力のステートマシン
```

### 14.2 CombatPresenter：イベントの再生

```gdscript
class_name CombatPresenter extends Node
var _pending: Array[CombatEvent] = []
var _cooldown := 0.0

func _on_event_emitted(e: CombatEvent) -> void: _pending.push_back(e)

func _process(delta: float) -> void:
    var speed := Settings.anim_speed * _backlog_boost() * (8.0 if _fast_forward else 1.0)
    _cooldown -= delta * speed
    while _cooldown <= 0.0 and not _pending.is_empty():
        var e: CombatEvent = _pending.pop_front()
        _play(e)                         # View / Fx / Audio に振り分ける
        _cooldown += Pacing.duration_of(e.kind)
```

- `Pacing`（定数表の Resource）：イベントの種類ごとの再生時間（ダメージ 0.18 秒、ドロー 0.21 秒、シャッフル 0.7 秒、死亡 0.6 秒……）。溜まりが 12 件を超えたら比例して加速する（最大 3 倍）。**加速するがスキップはしない**。画面クリックで 1.5 倍の早送り。
- 表示値とモデル値の分離：`UnitView` は自分で `shown_hp` / `shown_block` を保持し、`DAMAGED` / `BLOCK_GAINED` を再生したときにだけ `event.snapshot` で更新する。
- `is_idle()`：イベントの再生が終わってから、戦闘結果パネルの表示と「続ける」ボタンの有効化を許可する。
- **カードは再生中でも出せる**（テンポを止めない。2026-10-19）：`CombatScreen.can_play()` は再生の終わりを待たず、画面がプレイヤーのターンを見せている間（`presenter.player_turn_shown` = `TURN_STARTED` を再生してから `TURN_ENDED` / `COMBAT_ENDED` まで）なら真。`try_play` は出す直前に `presenter.catch_up()` で溜まっている演出を待たずに全部見せ（数字は一度に出る。HP などはモデルに追いつく）、それから新しいカードを通常のテンポで再生する。ターン終了とポーションは従来どおり `can_act()`（= 再生が終わっている + `can_play()`）で待つ。手札の「出せる」表示とカードの数値も再生中に更新する。

### 14.3 HandView

- `HandLayout.compute(i, n) -> Transform`（純粋関数）：横は等間隔、縦は放物線状に沈め、角度は線形補間。枚数が多いと自動で間隔を詰める。
- `CardView` は自分で目標の姿勢に向けて補間（`lerp`）する。ホバー中のカードは持ち上がり、拡大し、`z_index` を上げて隣のカードを押しのける。
- **1 枚ずつ配る**：手札の View は `piles.hand` を直接写さず、Presenter が `CARD_DRAWN` を再生した時点で 1 枚追加し、山札ボタンの位置から飛んでくる。手札から離れたカードは FX（飛び出し / ディゾルブ）に渡してから解放する。

### 14.4 HandInput ステートマシン

```
IDLE ──hover──▶ HOVER ──press──▶ DRAG（対象不要のカード）──プレイラインを越えて離す──▶ play_card()
                         │                     └──戻す──▶ IDLE
                         └──press(対象が必要なカード)──▶ AIM（TargetArrow を表示）──敵の上で離す──▶ play_card(target)
CHOOSING：pending_choice があればカード選択モーダルを開き、他の入力をロック
LOCKED：敵のターン / イベント再生中 / 戦闘終了
```

グローバルな入力の優先順位：モーダル（Esc で閉じる）> 照準の取り消し（右クリック / Esc）> 早送り（クリック）> ターン終了（Space / E）。入力は `InputMap` のアクションを使う：`ui_cancel`、`end_turn`、`fast_forward`。

### 14.5 カード面

`CardView` シーン：カードフレーム（種類ごとの `CardFrameSkin` Resource で画像と内側の余白を切り替え）、コストの宝石、名前、イラスト、種類、説明文（`RichTextLabel`、内容は `CardText` から）、アップグレードの印。状態：プレイ可能な縁取り / プレイ不可の暗転 / 選択中。ホイル（レアカード）はシェーダーのオーバーレイ。

### 14.6 3D の舞台（キャラクターと敵だけ 3D、カード・HUD・背景は 2D）

キャラクターと敵は 3D モデル（KayKit、`assets/models/`）で動かし、それ以外は 2D のまま。ファイルは `src/presentation/stage/`。

```
Field
├─ Stage (BattleStage：SubViewportContainer, stretch, mouse_filter = IGNORE)
│  └─ SubViewport（transparent_bg, own_world_3d, MSAA 4x）
│     ├─ Camera3D（真横の正投影。1 ワールド単位 = 90 px）  ├─ DirectionalLight3D  ├─ WorldEnvironment（環境光）
│     └─ StageActor × N（モデル + BoneAttachment3D の武器 + AnimationPlayer）
├─ PlayerView / EnemyRow の UnitView（HUD：インテント・名前・HP・ステータス。立ち絵の図形は描かない）
```

- **2D のレイアウトが正**：アクターの足元は毎フレーム `UnitView.portrait_rect()` の下辺中央に合わせる（`BattleStage.to_world` = `Camera3D.project_position`）。照準の当たり判定・カードの飛ぶ先・フローティング数字は今までどおり 2D の矩形で決まるので、`HandInput` と既存のテストは 3D を知らない。矩形の大きさはアクターの身長から決める（`UnitView.set_stage_mode`）。
- **見た目の表は表現層**（`ActorCatalog`。`EnemyData.id` → モデル・武器・動作ごとのクリップ・行動 id ごとの上書き）。コンテンツ層には 3D の参照を入れない（シミュレーションが 3D を読み込まない）。表に無い敵は 3D を出さず、従来の図形の立ち絵になる。
- **アニメーション**：`assets/models/animations/*.glb` は「Animation Library」としてインポートする（`.import` の `importer="animation_library"`）。骨格（Rig_Medium / Rig_Large）ごとに同じ骨の名前なので、ライブラリを各キャラの `AnimationPlayer`（`root_node = ..` で、トラックのパスは `Rig_Medium/Skeleton3D:骨`）にそのまま付ける。クリップ名は「ライブラリ名/クリップ名」。
- **イベント → 動作は `StageDirector`**（Presenter が 1 件ごとに呼ぶ）：
  - `lead_in(e)`：e を見せる**前**に待つ秒。攻撃の 1 撃（`BLOCKED` / `DAMAGED`、snapshot の `kind` が ATTACK、発生源が別のユニット）で `StageActor.strike()`（踏み込み 0.16 秒 + 当たる瞬間まで）を始め、その秒だけ待たせてから数字と HP を見せる。同じ 1 撃の `BLOCKED` → `DAMAGED` で振りかぶるのは 1 回。多段攻撃は撃数だけ振る（クリップを順に使う）。遠隔（`ranged`）の敵と**プレイヤー（`in_place`）は踏み込まずにその場で振る**（カードを続けて出すテンポを優先。次のカードの攻撃はクリップを頭から再生し直すので、前の振りの途中でもすぐ切り替わる。§14.2 の catch_up と組み合わせて、連打しても待たされない）。プレイヤーの動作は再生倍率も速い（`rate = 1.7`、敵は 1.3）。
  - `after(e)`：e を見せた**後**に必要な秒（`CombatPacing` の時間と大きい方を使う）。行動の始まりで攻撃以外の動作をする：`CARD_PLAYED`（スキルはブロックを得るなら構え、それ以外は使う動作、パワーは掲げる）、`ENEMY_TURN_STARTED`（`snapshot.intent` で守り / 強化 / 弱体化の動作）。被弾（`DAMAGED` の値 > 0 で白フラッシュ + Hit、ブロックで受けたら構えの被弾）、`UNIT_DIED` で死亡（倒れた姿勢のまま残る）、`COMBAT_STARTED` で敵の登場。
  - 当たる瞬間はクリップごとの表（`ActorCatalog.IMPACT`。手の速さが最大になる時刻を実測した値）。表に無いクリップは長さの 40%。
  - アクターの `AnimationPlayer` と移動の Tween には Presenter の倍率（設定の速さ × 溜まりの加速 × 早送り）を掛ける（`CombatPresenter.current_speed()` → `BattleStage.set_speed`）。
  - `presenter.instant`（テスト）のときは指示役を呼ばない。再生が終わったら `sync_from_model` で倒れているべきアクターを倒す。
- **③層の変更**：`ENEMY_TURN_STARTED` の `id` に行動 id、`snapshot.intent` にインテントの種類（行動の後には `current_move` が次の行動に変わっているため）。`BLOCKED` の snapshot に `kind`（トゲのような攻撃でないダメージで振りかぶらないため）。
- **向き**：真横から少しカメラ側に振る（`StageActor.FACING_YAW_DEG = 65`）。プレイヤーは右向き、敵は左向き。

---

## 15. エフェクト・効果音・時間

### 15.1 Fx

- `Fx` Autoload がオブジェクトプールを管理する：`Fx.spawn(&"floating_number", global_pos, {value = 12, style = &"poison"})`。
- エフェクトシーン（`scenes/fx/`）はそれぞれ `Tween` か `AnimationPlayer` を使い、再生が終わったらプールに戻す。
- 打撃の強さは `severity = ダメージ / 対象の最大 HP` で統一的に導出する。白フラッシュ、ノックバック、フローティング数字の大きさ、画面揺れ、効果音の段階はすべてこの同じ値を使う。
- 画面揺れ：`Field` ノードに `Shake` コンポーネントを付け、`FastNoiseLite` で滑らかな変位を作る。手札と HUD は揺らさない。
- シェーダー（`assets/shaders/`）：`card_foil`、`card_dissolve`、`shield_ring`、`soft_glow`、`unit_flash`（白フラッシュ / スイープ光 / リムライト）、`vignette`。

### 15.2 TimeFx

- `hit_stop(seconds)`、`slow_motion(scale, seconds)`：`Engine.time_scale` を変更し、`Time.get_ticks_msec()`（実時間）でカウントダウンして、終了時には必ず元に戻す。画面切り替え時に `TimeFx.reset()`。
- `Settings.slow_mo_enabled` で制御する。

### 15.3 Audio

- `SfxId`（列挙）+ `SfxBank`（Resource：`Dictionary[SfxId, AudioStream]`）。音声ファイルが割り当てられていればそれを使い、なければ `SfxSynth` がプロシージャルに `AudioStreamWAV` を生成してキャッシュする。素材ゼロでも効果音がすべて揃う。
- `Audio.play(id, pitch_jitter := 0.05)`：`AudioStreamPlayer` のプール（約 12 個）。Bus：`Master / SFX / Music / UI`。
- `CombatAudio`：イベント → 効果音の**唯一の**対応表（`Dictionary[CombatEvent.Kind, Callable]`）。Presenter がイベント再生時に呼ぶ。
- ボタンの効果音：`StyledButton` シーンにホバー / クリック音を内蔵し、すべてのボタンがこれを使う。

---

## 16. ローカライズ

- Godot 組み込みの **Translation** の仕組みを使う：`localization/ui.csv`、`localization/content.csv`（列は `keys, zh_CN, en`）を `.translation` としてインポートする。
- **常にキーを使う**（`UI_MENU_NEW_RUN`、`CARD_STRIKE_NAME`）。Control のテキストにはキーをそのまま入れ、`auto_translate` で自動翻訳させる。動的な文字列は `tr("UI_GOLD_GAIN").format({"n": 12})`、単数 / 複数は `tr_n()`。
- コンテンツのキーは id から導出する（`CardData.name_key()`）。`.tres` の `text` フィールドは中国語の原文で、ツール `export_content_strings` が全コンテンツの原文を `content.csv` の `zh_CN` 列に書き出す。翻訳者は `en` 列だけを編集する。
- 言語の切り替え：`TranslationServer.set_locale()` + `Settings.locale`。`NOTIFICATION_TRANSLATION_CHANGED` で、再計算が必要な View（カードテキスト）が自分で更新するので、**画面全体を作り直す必要はない**。
- フォント：Theme のデフォルトフォントを LXGW 文楷にし、必要に応じてフォールバックを追加する。

---

## 17. コンテンツのワークフローとツール

### 17.1 編集方法

- Godot の FileSystem で `.tres` を新規作成 / 複製し、Inspector で編集する。入れ子のブロックは「新規 DamageEffect」などのメニューから選ぶ。
- よく使うブロック（「選択した敵へ」「自分」「固定 6」）は `content/presets/` に置き、ドラッグして再利用する（ブロックはステートレスなので共有インスタンスでも安全）。

### 17.2 コンテンツインデックス（`addons/trycard_tools`）

- エディタプラグインに **「コンテンツインデックス再構築」** ボタンを用意する：`res://content/**.tres` を走査し、型ごとに `content_library.tres` に登録し、id の重複を検査する。
- 実行時の `Content` はこのインデックス 1 つだけを読み込む（エクスポート後はファイルシステムの走査が信頼できないため、インデックスが最も確実）。
- 保存時（`resource_saved`）に自動で再構築し、忘れを防ぐ。

### 17.3 コンテンツバリデータ

同じ `ContentValidator` をエディタプラグイン（ボタン + 出力パネル）とテストで共用する：
- id が一意かつ空でない。すべての参照が null でない。アップグレードの連鎖に循環がない。
- カードテキストの `{label}` に対応する効果が存在し、効果の label がすべて使われている。
- カードの `aim` と効果の対象が一致している（例：効果がランダムな敵を狙うのに、プレイヤーに対象選択を求めている → 警告）。
- カードプールで使われるキーワードにはすべて `KeywordData` がある。
- 敵の技の id が一意で、`opening` が参照する id が存在する。
- 翻訳表にすべてのコンテンツのキーがある。
- **ステートレス検査**：各ブロック / Behavior / AI / RunEffect のスクリプトについて `get_script_property_list()` を取得し、`@export` のフィールド以外にメンバ変数がないことを確認する。

### 17.4 編集補助（`@tool`）

- `CardPreview` エディタパネル：`CardData` を選ぶとカード面を即座に表示する（本物の `card_view.tscn` を使う）。
- `EditorInspectorPlugin`：`ValueSource` フィールドの横に「整数クイック入力」を用意し、自動で `Fixed` を作る。
- 最初のコンテンツは `EditorScript`（`tools/seed_content.gd`）で `GameDesign.md` 付録 A に従って `.tres` を一括作成し、以降はすべて Inspector で保守する。

---

## 18. テストアーキテクチャ

### 18.1 フレームワークと実行

- GUT を使い、テストは `res://tests/` に置く。コマンドラインからヘッドレス実行：`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`（`tools/run_tests.ps1` にまとめる）。

### 18.2 テスト支援

- `tests/support/fixtures/`：最小限のテストコンテンツ（数枚のカード、2 体の敵、いくつかのステータス）。正式コンテンツとは切り離し、バランス調整でルールのテストが壊れないようにする。
- **Builder**：`CombatBuilder.new().with_hand([...]).with_enemy(e, hp).with_status(...).build()`、`RunBuilder`。各テストは自分に関係する部分だけを書けばよい。
- `CombatHarness`：`play("strike", enemy0)`、`end_turn()`、`assert_hp(enemy0, 34)`、`events_of(DAMAGED)`。

### 18.3 テストの階層

| 階層 | 範囲 |
|---|---|
| ユニット | 各ブロック、各 Behavior、ダメージパイプライン、山のルール、AI の判断、マップ生成ルール、報酬 / ショップ、RngStreams、Serializer |
| 統合 | カードプレイの全フロー（カード選択の一時停止、エコー、トリガー順序を含む）、ターンの流れ、イベントの選択肢、セーブ / ロードの再実行 |
| 不変条件 | カード枚数の保存、プレビューが乱数を消費しない（プレビュー前後で `rng.save()` が同じ）、インテントの数字 == 実際のダメージ、戦闘後にコンテンツ Resource が変更されていない |
| シミュレーション | `RandomBot` が 1000 戦・200 ランを実行：クラッシュしない、ハングしない（ActionQueue のガード）、セーブ / ロードで中断して続行した結果が一致する |
| 正式コンテンツ | `ContentValidator` が `content/` 全体で通る。すべてのカードが `CombatBuilder` 上でプレイできる |

### 18.4 アーキテクチャ門番テスト

- `src/content`、`src/domain`、`src/flow` のソースコードを走査し、`extends Node`、`get_tree`、`await`、`randi(`、`randf(`、`.shuffle(`、`.pick_random(`、Autoload 名への参照が出現しないことを確認する。違反すればテストが失敗する。レイヤーのルールを自覚頼みにしない。
- 実装：`tests/support/layer_rule_scanner.gd` + `tests/unit/architecture/test_layer_rules.gd`。コメントと文字列は除外して照合する。`.shuffle()` / `.pick_random()` は**引数なし**（= Array のグローバル乱数版）だけを違反とし、`rng.shuffle(stream, items)` は通す。ファイル I/O（`FileAccess` / `load(` など）と実時間（`Time.` / `OS.` / `Engine.`）も違反とする。Autoload 名は `project.godot` から自動取得する。検査器自体の正例 / 負例テストも持つ。

---

## 19. デバッグツール

- `combat_sandbox.tscn`：Inspector でエンカウント、デッキ、レリック、シードを指定してすぐに戦える。カードの調整や手触りの調整に使う。
- `debug_overlay.tscn`（デバッグビルドのみ、F1 で切り替え）：ログ、現在の乱数ストリームの状態、ワンクリックで「戦闘に勝つ / カード追加 / レリック追加 / HP 設定 / ゴールド追加」、イベントログの閲覧、`time_scale` の調整。
- シード：メインメニューで固定シードを入力できる（デバッグビルド）。

---

## 19.5 M1 実装メモ（本書との差分）

- **抽象メソッドは M2 で付ける**：M1 では基底クラスに `@abstract` を付けて（Inspector の「新規作成」に出ないように）、`apply()` / `_raw()` / `_test()` / `_resolve()` は `push_error` するだけの既定実装にしている。M2 で各サブクラスを実装するときに `@abstract` メソッドに変える。
- **ブロックのクラス名**：値の出所は `XxxValue`（`FixedValue`、`ScaledValue`、`IfValue` …）、条件は `XxxCondition`、対象ルールは `ChosenTarget` / `SelfTarget` / `AllEnemiesTarget` …、ラン中の効果は `XxxRunEffect`、ラン中の条件は `XxxRunCondition`（`src/content/run_effects/conditions/`）。
- **追加したブロック**：`IfValue`（条件で値を切り替え）、`RemoveStatusesEffect`（極性でまとめて解除）、`WeightedEffects`（`RandomChoiceEffect` の選択肢）、`TargetRule.exclude_chosen`（「他のすべての敵」）、`CombatBehavior.Hook.ROUND_END`（減衰。`GameDesign.md` 付録 C の C2）。
- **`GuardianAI` は作らない**：`ScriptedAI.phase_change_effects`（データ）で「デバフ解除 + 筋力 5」を表す。
- **`Pile`**（`src/content/data/pile.gd`）：山（`Pile.Id`）と置き場所（`Pile.Place`）の列挙を共有する。
- **ContentValidator はメソッドを呼ばない**：エディタ上では `@tool` でないスクリプトのメソッドが動かないので、エクスポートされたプロパティを汎用に辿って検査する。必須フィールドは `REQUIRED` 表に書く。`addons/trycard_tools/` に置き、`ContentIndexBuilder` と共にプラグインとテストから使う。
- **id は種類ごとに一意**（§5.1 の「全体で一意」から変更）。
- **`tools/seed_content.gd` は `SceneTree` スクリプト**（`EditorScript` ではなく）：コマンドラインから実行でき、生成後にインデックスを再構築して検証する。
- **②層から③層の型への依存**：ブロックのメソッドの引数（`EffectContext`、`Combat` など）は③層の型である。依存の向きの例外として認める（ブロックは「データとして保存されるルール」なので）。M1 ではこれらを空のスタブとして置いている。

## 19.6 M2 実装メモ（本書との差分）

- **ターンの手順は連鎖で積む**（`CombatTurnFlow`）：各ステップの最後に次のステップを `push_bottom` する。最初に全ステップを積むと、途中で発生したトリガー（死亡など）が後続のステップより後ろになり、「プレイヤーが死んだのに次のターンが始まる」順序の不具合になるため。
- **循環参照は弱参照で断つ**：`BehaviorHost.owner`、`HookDispatcher` / `CombatTurnFlow` から `Combat`、`EffectContext.combat` は WeakRef。キューに積む Callable は self を捕まえるラムダにせず、メソッドの `bind` にする。これを守らないと戦闘 1 回ごとに数千個のオブジェクトがリークする（実測）。
- **`EnemyAI.choose_move(unit: Combatant, combat)`**（§9.1 の `mind` ではなくユニットを渡す。条件の評価に発動者が要るため）。フェーズは `EnemyAI.phase_after_damage(unit)` で判定する。
- **`Combat.create(setup: CombatSetup)` → `start()`**。`CombatController.begin(setup)` が両方を行う。テストは `CombatController.from_combat()` で開始前に状態を整えられる。結果は `CombatResult`。
- **補正型 Hook の calc**：ダメージは `DamageCalc`、それ以外（ブロック・回復・ステータス付与・コスト・行き先・プレイ回数・ターンのエネルギー / ドロー）は汎用の `HookCalc`。
- **`CombatEvent.Kind` に追加**：`CARD_MOVED`、`CARD_UPDATED`（コスト・成長値の変化）、`CHOICE_RESOLVED`、`PHASE_CHANGED`。カードのイベントは `value` = カードの uid、`id` = カードの id。
- **`CombatBehavior.Hook.ROUND_END`** を追加（全員の行動の後。減衰の処理）。
- **`ActionQueue` の暴走ガード**は `assert` ではなく上限で止めて戦闘を `ABORTED` にする（リリースビルドでも働く）。
- **`RngStreams`**：ストリームの起点は自前の FNV-1a、`save()` は state を文字列で返す（JSON で 64bit 整数が壊れるため）。

## 19.7 M3 実装メモ（本書との差分）

- **`RunPhase` は `src/domain/run/` に置く**（§3 では `flow/`）。`RunState` がフェーズを持つので、③層から④層への依存を作らないため。
- **ノードの中だけの状態はセーブしない**：§10.1 の `shops: Dictionary[int, ShopStock]` はやめて、現在のノードの `shop` 1 つにした。`event` / `event_choice` / `pending_requests` / `rest_used` も同じくノードの中だけ。チェックポイントは「ノードの内容を生成する前（node_entered）」と「ノードを離れた後（returned_to_map）」にしかないので、内容は再開時に同じ乱数状態から作り直せば同じになる（マップは前にしか進めないので、同じショップに戻ることもない）。
- **`RunController` の公開 API**：`start_new(seed, interactive)`、`resume(state)`、`enter_node`、`choices`、`acknowledge_combat_end`、`take_reward(item_index, card_index)`、`buy(index)` / `buy_removal(card)` / `buy_upgrade(card)`、`event_option_available` / `choose_event_option` → `EventOutcome`、`pending_request` / `request_candidates` / `request_pick_count` / `resolve_request(indices)`、`rest_heal` / `rest_upgrade(card)`、`discard_potion`、`leave_node`（`can_leave`）、`advance_act`、`abandon`。
- **`combat_started(combat)` signal**：戦闘を作った直後、`start()`（初手のドロー）の前に出す。画面はここで `event_emitted` に接続すれば最初のイベントから受け取れる。
- **戦闘系の 3 つの Handler は `CombatNode` を継承**する。戦闘の再開は `active_encounter` から `RunController.resume()` が行う（イベントが予約した戦闘も同じ経路で再開できるため、`on_resume` は使わない）。
- **報酬は `Reward`（`items: Array[RewardItem]`）**、ショップの商品は `ShopStock`（`items: Array[ShopItem]`）。削除 / アップグレードのサービスは在庫ではなく `RunController` のメソッド（価格は購入回数から計算）。
- **イベントのカード選択**：効果は `RunEffectContext.requests` に `RunChoiceRequest`（REMOVE / UPGRADE / PICK）を積み、`RunController` が `state.pending_requests` として 1 つずつ処理させる。候補が 0 のリクエストは飛ばす。全部処理するまで `leave_node` できない。
- **`RunSerializer` はインスタンス**（`from_dict` が失敗したら null を返し `error` に理由）。列挙は名前（`"MAP"` など）、シードと乱数の state は文字列で保存する。`SaveMigrations.migrate(d, steps, target)` は移行の列を引数で差し替えられる（テスト用）。
- **`SaveManager`** は M3 で実装：`attach(run)` / `detach()`、`save_run` / `load_run(content)`（失敗は null と `last_status` = NONE / OK / RECOVERED / CORRUPT）、`delete_run`。`run_path` はテストで差し替える。破損は `Log.warn`（`push_error` にしない）。
- **乱数ストリームの割り当て**：マップの形と種類 = `map`、エンカウントの割り当て・ボス・イベント戦闘の抽選 = `encounter`、イベントの割り当てとイベントの効果 = `event`、戦闘報酬 / 宝箱 = `reward`、ショップ = `shop`。
- **テスト支援**：`RunFixtures`（テスト用の複数アクトのライブラリ、HP を大きくした config、ノードの種類の書き換え、戦闘の勝敗の強制）、`RunBot`（ラン全体をランダムに進める。乱数は 1 本だけなので、チェックポイントで state を記録すれば再開後に同じ判断を再現できる）、`RunRecorder`（全チェックポイントの記録と、そこからの再開）。

## 19.8 M4 実装メモ（本書との差分）

- **ファイルの配置**：`src/presentation/` の下を `main/`（Main・ScreenHost・ModalHost・Screen・Modal）、`common/`（`UiText`＝画面の文言、`UiGlyphs`＝図形アイコンの文字と色）、`widgets/`（`CardView`・`CardListModal`・`TopBar`・`PotionBar`・`GlyphBadge`）、`combat/`（`CombatScreen`・`CombatPresenter`・`CombatPacing`・`HandView`・`HandLayout`・`HandInput`・`UnitView`・`TargetArrow`）、`map/`（`MapView`）、`screens/`、`fx/`、`debug/`（`combat_sandbox`）に分けた。
- **汎用カード選択パネルは `CardListModal` 1 つ**（§3 の `card_picker_modal` と `pile_viewer_modal` を兼ねる）。`max_count = 0` で閲覧、`min = max = 1` はクリックで即決定。テストと自動操作は `choose(indices)`（クリックと同じ経路）。
- **`Modal.cancel()` と `cancelled` signal を追加**。ModalHost は Esc で `top().cancel()` を呼ぶ（`cancellable = false` なら何もしない）。
- **`Screen` が `run` と `modals` を持つ**：Main が `enter({run, modals, phase})` で渡す。画面は `run_changed`（トップバーの更新）と `main_menu_requested` を出す。フェーズの遷移は `run.phase_changed` を受けた Main だけが行う。
- **戦闘画面は開戦からの全イベントを再生する**：`CombatPresenter.bind()` は `Combat.events`（それまでのログ）を溜まりに入れてから `event_emitted` に接続する。そのため `combat_started` signal を使わなくても初手から再生できる（ロードからの再開、sandbox も同じ経路）。
- **山の枚数は Presenter が「カードの表示上の場所」（uid → 山）で数える**：開戦時は全カードを山札とし、`CARD_DRAWN` / `CARD_PLAYED` / `CARD_DISCARDED` / `CARD_EXHAUSTED` / `CARD_MOVED` / `CARD_CREATED` / `PILE_SHUFFLED` で動かす。再生が終わるたびに `sync_from_model()` でモデルと突き合わせる（手札・HP・ブロック・ステータス・エネルギー・ポーション）。
- **③層の変更：プレイ後の行き先で `CARD_MOVED` を出す**（`Combat._finish_play`。捨て札 / 山札 / パワー。廃棄は従来どおり `CARD_EXHAUSTED`）。表現層がプレイしたカードの行き先と山の枚数を知るため。
- **入力のロックは `CombatScreen.can_act()` 1 か所**：再生中・カード選択中・モーダル表示中・戦闘終了・敵のターン・キューが空でないときは操作できない。
- **ポーション**：戦闘中は `CombatScreen` の `PotionBar`（§14.1 の Hud）、それ以外はトップバーの `PotionBar`（捨てるだけ）。トップバーは戦闘中はポーションを隠す。
- **Fx**：`Fx` Autoload が自前の CanvasLayer（10）とプールを持つ。M4 はフローティング数字だけ（`FxNode` を継承）。
- **最小限の画面は `PanelScreen`**（中央のパネルにタイトル・本文・ボタンをコードで並べる）。M5 で作り込むときにシーンのレイアウトに置き換えてよい。
- **入力のアクション**：`end_turn`（Space / E）を `project.godot` に追加。早送りは戦闘画面の空いている所の左クリック（`_gui_input`）。戦闘中のボタンは `focus_mode = NONE`（Space がボタンの押下にならないように）。
- **`ScreenHost` のフェードの Tween は host 側に作る**：旧画面は `PROCESS_MODE_DISABLED` にするので、旧画面の Tween だと止まって解放されない（M0 の不具合。回帰テストあり）。
- **テスト支援**：`UiBot`（画面を操作してランを完走させる）。Main に `config_override`（テスト用の RunConfig）。

## 19.9 3D の戦闘キャラクター 実装メモ（2026-10-19、M4 の後に前倒し）

- 設計は §14.6。`src/presentation/stage/`：`BattleStage`（舞台）、`StageActor`（1 体）、`StageDirector`（イベント → 動作）、`ActorCatalog`（見た目の表）。
- 素材：KayKit Adventurers 2.0 / Skeletons 1.1（SOURCE 版のモデル）と KayKit Character Animations 1.1（戦闘モーション。キャラのパックの General には攻撃が無い）。すべて CC0。ライセンス文は `assets/models/LICENSE_*.txt`。
- 敵は名前と見た目だけ骸骨の軍勢に変えた（`GameDesign.md` §11.2。id・行動・数値は変えていない）。
- テスト：`tests/unit/presentation/test_stage.gd`（表が全部の敵を覆い、素材とクリップが実在する / 踏み込み・被弾・死亡 / 指示役ありで戦闘の再生が最後まで進む）、`tests/unit/combat/test_presentation_events.gd`（③層の追加分）。
- ヘッドレス（テスト）では 3D は描画されないだけで動く。見た目の確認は描画ありのスクリーンショット（skill trycard-dev）。

## 19.10 M5 実装メモ（本書との差分）

- **ツールチップ**（§13.4）：Main に Tooltip の CanvasLayer は作らなかった。
  - 一般の Control：`GlyphBadge` と `TipButton`（`Button` の代わり。`PanelScreen.add_button` が使う）が `_make_custom_tooltip` で `TooltipPanel.for_tooltip(tooltip_text)` を返す。`tooltip_text` は「1 行目 = 見出し、2 行目以降 = 本文（BBCode 可）」の書式。Godot は返した Control を自前のポップアップ（テーマの `TooltipPanel` の枠）に入れるので、中身は枠を描かない。ポップアップは中身の最小サイズで大きさを決めるため、本文の高さは `TooltipPanel.body_size()` でフォントから先に計算して最小サイズに入れる（`fit_content` だと文字の切れた小さな枠になった）。遅延は `gui/timers/tooltip_delay_sec = 0.25`。
  - カード：`CardView` のホバーで `CardTips`（CanvasLayer 100）をカードの子に作り、カードの横に `TooltipPanel` を縦に並べる。CanvasLayer なのでカードの modulate（暗転・半透明）・拡大・回転を受けず、モーダルより上に出る。中身は `UiText.card_terms()`（`KeywordScan`）。手札で持ち上げる（`HandView.set_held`）と消す。
  - 文言は `UiText`（`intent_text` / `block_text` / `relic_text(data, counter)` / `potion_text` に用語を付ける / `terms_of(scan)`）。
- **アップグレードの比較**：`CardListModal` に `upgrade_preview`（1 枚選びのときだけ）。クリック → `open_compare(i)`（`%Compare` に前後の `CardView` を 1.3 倍で並べ、一覧 `Margin` は隠す）→ `confirm_compare()` で `picked`。`cancel()` は比較中なら一覧に戻るだけ（キャンセル不可のパネルでも）。テストと UiBot は `choose()` / `open_compare()` / `confirm_compare()` / `close_compare()`。
- **画面**：ショップ / イベント / 休憩 / アクト移行は `PanelScreen` のまま作り込んだ（シーンのレイアウトには置き換えていない）。`PanelScreen.panel_width` を追加（ショップは 1560）。ショップは `offer_views` / `price_labels`（商品の番号 → 表示）をテスト用に公開する。
- **トップバー**：`HpBar` を追加。`set_hp(hp, max_hp, animate)` は戦闘外なら表示中の値から Tween で動かす。トップバーを隠すと `shown_hp = -1` に戻り、次のランの最初の表示は動かさない。
- **Main**：テスト用に `content_override`（ContentLibrary の差し替え。複数アクトの構成でアクト移行の画面を通す）。
- **SaveManager**：名前の変更 / 削除を `_retry()` で少し待って数回やり直す（Windows でまれに失敗した。§12.3 のアトミック書き込みの手順は同じ）。
- **テスト**：`tests/unit/presentation/test_m5_screens.gd`（ツールチップ・比較・ショップ・イベント・休憩・アクト移行とトップバー）、`tests/sim/test_ui_restart.gd`（再起動からの再開。環境変数 `TRYCARD_RESTART_RUNS`、既定 2、約 26 秒）。

## 19.11 パーティクルのエフェクト 実装メモ（2026-10-19、M6 の一部を前倒し）

- **範囲**：攻撃のヒット、ブロック（獲得と、攻撃をブロックで受けたとき）、カードを出したとき、敵の死亡。見た目はトゥーン調（KayKit に合わせ、縁のはっきりした形・単色・通常の混合）。ノックバック・画面揺れ・ヒットストップなど残りの M6 は未着手。
- **3D（キャラに付くもの）**：`BattleStage.spawn_fx(kind, at, facing, size)` が `scenes/fx/stage/*.tscn` を舞台の SubViewport に出す。根の `StageEffect` が子の GPUParticles3D（one_shot・`local_coords`）を一斉に出し、いちばん長い寿命が過ぎたら自分を消す（Presenter の速さを `speed` で掛ける）。§15.1 の `Fx` は 2D の CanvasLayer なので、3D の舞台の物は Fx を通さない。
  - `StageDirector.after`：`DAMAGED`（攻撃の種類だけ。大きさ = 0.9 + 1.2 × ダメージ / 最大 HP）→ `hit`、`BLOCKED` → `guard`、`BLOCK_GAINED` → `block`。打撃は相手の体の攻撃側に出し、`facing` で破片の飛ぶ向きを攻撃の向きに合わせる。
  - 死亡：`StageActor` が消え始めるときに `vanishing` を出し、`BattleStage` が `death`（煙・骨・魂）を出す。倒れるクリップを最後まで待つと遅い（骸骨は 2 秒）ので `StageActor.DEATH_HOLD_MAX`（0.9 秒）で打ち切って消し始める。
  - 舞台の `SubViewportContainer` の材質を乗算済みアルファにした（透明な SubViewport に描いた半透明が暗く濁るため）。消えていく死体の縁も同じ理由で正しくなる。
  - 初回のシェーダーのコンパイルでカクつかないよう、`_warm_up` が全種類を見えない大きさで 1 回出す。
- **2D（UI）**：`Fx.spawn(&"card_burst", 行き先, {color, delay = HandView.PLAY_FLIGHT})`。カードの種類の色は `UiGlyphs.CARD_BURST_COLORS`。
- **追加（同日、2 回目）**：ブロック破砕・回復・毒（付与と継続ダメージ）・筋力アップ・弱体・脆弱・敵の登場・勝利。
  - 3D は `BattleStage.spawn_on(kind, actor, 身長の割合)`：大きさを身長に合わせ、`StageEffect.anchor` でアクターに付いていく（開戦直後はアクターの位置がまだ決まっていないので、登場の土もこれで足元に合う）。
  - 対応（`StageDirector.after`）：`BLOCK_CLEARED` と「`BLOCKED` で snapshot.block = 0（受けきれずに割れた）」→ `shatter`、`HEALED` → `heal`、`STATUS_APPLIED`（value > 0 のときだけ）→ `StageDirector.STATUS_FX` の表（poison / strength / weak / vulnerable。表に無いステータスは出さない）、`DAMAGED` の種類 STATUS（毒）→ `poison_tick`、`COMBAT_STARTED` → 敵ごとに `spawn`。
  - 勝利：`COMBAT_ENDED` の value = 1 で `Fx.spawn(&"victory")`（`VictoryFx`：画面の下の両角から紙吹雪、下辺から光の粒）。2D の汎用部分は `ParticleFx`（`tinted` に挙げた子だけ染める。card_burst も同じスクリプト）。
- **素材**：`assets/textures/fx/*.png` は `tools/fx_textures.py` が作る自作の図形（外部素材なし）。
- **テスト**：`test_stage.gd`（全エフェクトの形と寿命での解放、死亡でのエフェクト、戦闘の再生で打撃のエフェクトが出る、イベント → エフェクトの対応表）、`test_widgets.gd`（card_burst のプール、勝利の紙吹雪の位置）。

## 19.12 戦闘報酬とカードの 3 択 実装メモ（2026-10-20、StS2 の録画に合わせた）

- **勝利 → 報酬**：ラン中の勝利では §14.1 の `ResultPanel` を出さず、`CombatScreen.VICTORY_HOLD`（1.1 秒）後に自動で `continue_after_result()`。敗北と sandbox は従来どおりパネル。待っている状態は `result_pending()`（テスト・UiBot・撮影スクリプトはこれを見る）。
- **戦場を残す**：`Main.show_phase` が「戦闘画面 → REWARD」のときだけ `ScreenHost.show_screen(..., keep_backdrop = true)`。旧画面は破棄せず `exit()` → `enter_backdrop()`（`Screen` の仮想関数。`CombatScreen` は入力・再生・手札を止め、操作用の表示をフェードで消す。3D のキャラと環境エフェクトは動いたまま）で `ScreenHost.backdrop` に残り、次の切り替えで一緒に破棄する。報酬画面には `battle_behind = true` が渡る。再起動から報酬で再開したとき（戦闘画面が無い）は `CombatScreen.backdrop_index_of(run)` で同じ背景画像を自前で出す。宝箱は背景なし。
- **RewardScreen**（`PanelScreen` から `Screen` 直接に変更、コードで組む）：暗幕（後ろへの入力も止める）・青い石のパネル・羊皮紙のリボン・行（`RewardRow`：青い帯 + アイコン、ホバーで四隅に金のカギ）・右下の赤い矢印（未受け取りがあれば「スキップ」、無ければ「進む」）。受け取った行は `play_remove()` で縮んで消え、下が詰まる（`rows` = 項目の番号 → 行）。ゴールドは `TopBar.set_gold` が 1 ずつ数え上げる（戦闘外。0.8 秒）。
- **カードの 3 択**：`CardListModal` の引数 `showcase = true` で `CardShowcase`（パネルなし・横 1 列・リボン・六角のスキップ・目のボタン）。1 枚選びかつ `SHOWCASE_MAX`（5）枚以下のときだけ。それ以外は従来の一覧。使う所：報酬、イベントの PICK、戦闘中のカード選択。`dim = false` で暗幕を出さない（報酬画面が暗くしてある）、`fly_to` で選んだカードの飛び先（上部バーのデッキ = `TopBar.deck_center()`）。
- **演出のタイミング**（録画 30fps で実測）：Loot のパネルは 1 フレームで消える。カードは中央に重なった暗い影から 0.2 秒で左右に広がる（1 フレームで 6 割進む ease-out = TRANS_QUART）。リボンは 20px 下から上がる。ホバーは 0.8 → 1.0 倍を 0.07 秒、戻りは 0.15 秒。隣は外へ 14px。レア（`UiText.frame_rarity` = RARE）の後ろでは `card_rays.gdshader` の金色の放射光がずっと回る。選んだら、ほかは 0.12 秒で消えてから決定し、選んだカードは画面の外の CanvasLayer に移ってデッキへ縮みながら飛ぶ（パネルを閉じても飛び続ける）。`choose()`（テスト）は演出なしで即決定。
- **目のボタン**：強化後の表示に切り替える（選ぶのは元のカード）。強化版のあるカードが 1 枚も無いとき・戦闘中のカード（動的な説明）では出さない。
- **素材**：`tools/reward_ui.py`（PIL）→ `assets/textures/ui/reward/`（仮の自作。同じ名前の PNG で差し替えられる）。リボンとボタンの文字は `banner_mincho.ttf`（`tools/banner_font.py` の `KANJI` に「品宝箱選進」を追加）。
- **イベント画面**（`EventScreen` を `PanelScreen` から `Screen` 直接に変更）：背景 `event_chamber.jpg` + 右を暗くする横のグラデーション、右の列（画面幅の 0.5〜0.92）に見出し（`banner_mincho`、金）・本文（RichTextLabel、中央揃え）・選択肢の帯（`EventOptionButton`）。帯は Button ではなく `PanelContainer`（Button は子の大きさで伸びず、折り返しのある効果の行が切れた）。クリック = `pressed`、選べない = `disabled`（理由を赤みの行で）。帯は `MarginContainer` の入れ物に入れ、入ってくる演出は入れ物の左右の余白を同じだけずらして右から滑り込ませる（コンテナの中で position を動かすと並べ直しで崩れるため）。`option_buttons` が表示中の帯。効果の文は `EventOption.detail`（データに追加。`seed_content._option` は「名前（効果）」を分けて入れる）、色付けは `UiText.event_detail_markup`（`EVENT_DETAIL_COLORS` の正規表現）。見出しの漢字は `banner_font.py` がイベントの title から自動で含める。
- **休憩所**（`RestScreen` を `PanelScreen` から `Screen` 直接に変更）：背景 `rest_campfire.jpg` の焚き火に、`campfire_glow.gdshader`（楕円の光の明滅）・`campfire_flame.gdshader`（fbm で揺らぐ涙形の炎、加算）・火の粉（GPUParticles2D）を重ねる。位置は絵の px（`FLAME_RECT` / `GLOW_RECT` / `EMBER_AT`）で持ち、背景と同じ「覆うように拡大」の写し方で画面へ（`_layout`）。タイルは `RestTile`（`tools/rest_ui.py` の仮の絵、ホバーで `tile_frame.png`）、`tiles` が表示中のタイル、説明 / 結果は `desc_text()`。選んだ後は `ProceedArrow`（報酬画面と共用の右下の赤い矢印。`slide_in()` で滑り込む）。操作は従来どおり `rest()` / `open_upgrade()` / `leave()`。
- **宝箱の部屋**（`TreasureChestView`。`RewardScreen` が宝箱のマスのときだけ `chest` に持つ）：背景 `treasure_vault.jpg` + `god_rays.gdshader`（真上から、金色）。絵の宝箱の輪郭は絵の px の多角形 `CHEST_POLY`（PIL で絵に重ねて合わせた）で、ホバーは `Line2D`（白い輪郭）+ `Polygon2D`（薄い加算）、当たり判定は `Geometry2D.is_point_in_polygon`。`open()` は白金の閃光（揺らさない最前面）と揺れ（`_view` = 背景・光・粒の入れ物の position）の中で、開いた絵 `treasure_vault_open.jpg`（同じ構図。宝箱の外の差は平均 2〜6 なので重ねて切り替えられる）をフェードで重ね、中身（`MOUTH`）から光（halo の拡大）・回る光の筋（`card_rays.gdshader`）・衝撃の輪（`fx_ring`）・金貨の爆発（one_shot 80 粒）と噴水（`FOUNTAIN_TIME` 秒吹き続ける 56 粒）・宝石（色相のばらつき）・虹色のきらめき（加算）を出し、`OPEN_TIME` 後に `opened` → 報酬画面が暗くしてパネルを出す。開く前は暗幕が入力を通す（`MOUSE_FILTER_IGNORE`）。`take(i)` は開く前でも演出なしで開けてから受け取る（テスト・UiBot）。何か受け取り済みで再開したら開いた状態から。
- **テスト**：`test_screens.gd` の `test_combat_screen_play_win_and_reward`（パネルなしで報酬へ、戦場が背景に残り、報酬を離れると消える）と `test_reward_rows_and_card_showcase`（行の数、showcase、目のボタン、スキップで行が残る、選ぶとデッキに入って行が消える）。

---

## 20. 拡張ガイド（X を追加したい）

| やりたいこと | 方法 | コード変更 |
|---|---|---|
| 新しいカード / ポーション / レリック / ステータス / 敵 / イベント（既存ブロックで） | `.tres` を新規作成 → インデックス再構築 → 検証 | なし |
| 新しい即時効果 | `effects/impl/` に `CardEffect` サブクラスを 1 つ追加（`apply` + `preview`） | 1 ファイル |
| 新しい値の出所 / 条件 / 対象ルール | 対応するフォルダにサブクラスを追加 | 1 ファイル |
| 新しい持続ルール（ステータス / レリックの挙動） | `behaviors/impl/` に `CombatBehavior` を追加し、`hooks()` を返す | 1 ファイル |
| 新しい割り込みタイミング | `CombatBehavior.Hook` にビットを 1 つ追加し、エンジンの適切な位置で `hooks.notify/modify` | エンジン 1 か所 |
| 特殊な敵の挙動 | まず `priority` / `forced_when` / `phases` で試し、無理なら `EnemyAI` のサブクラスでフックをオーバーライド | 1 ファイル |
| 新しいイベント効果 / 条件 | `run_effects/impl/` または `RunCondition` のサブクラス | 1 ファイル |
| 新しいマップノード種別 | `MapNode.Type` + `NodeHandler` 1 つ + 画面シーン 1 つ + `main.tscn` の対応表 | 3 か所 |
| 新しいセーブ項目 | `RunState` + `RunSerializer` の両側。意味が変わるならバージョンを上げて移行を追加 | 2 か所 |
| 再生テンポ / 打撃の手触りの調整 | `Pacing` Resource、`Fx` シーンのパラメータ | なし |
| 新しい効果音 | `SfxId` に 1 項目追加、`SfxBank` に音声を割り当て（または合成レシピを追加）、`CombatAudio` に対応付け | 2 か所 |

---

## 21. ルール一覧（必須）

1. **コンテンツ Resource は実行時に読み取り専用。** 可変な状態は実行時オブジェクトにだけ置く。
2. **ブロック / Behavior / AI / RunEffect はステートレス。** `@export` の設定フィールドだけを持つ。
3. **②③④ 層は SceneTree に触れず、`await` せず、ファイルを読み書きせず、グローバル乱数を使わず、Autoload を参照しない。**
4. **戦闘の変化はすべて `ActionQueue` を通す。トリガーは常に `push_bottom`。** 効果の中から別の効果を直接再帰呼び出ししない。
5. **ダメージの入り口は `Combat.deal_damage()` だけ。表示される数字はすべて同じプレビューパイプラインから得る。**
6. **プレビューは状態を変えず、イベントを出さず、乱数を消費しない。**
7. **ルール層はイベントを書くだけで読まない。表現層はモデルを読むだけで、書き込みは Controller 経由のみ。**
8. **フローの遷移は `RunController` だけが行う。** 効果も画面もフェーズを直接切り替えない。
9. **乱数の分離：乱数の種類ごとに決まったストリームを使う。**
10. **4 つのセーブチェックポイントの位置は動かさない。**
11. **戦闘中の一時的な数値は、セーブするか、戦闘終了時にクリアするかのどちらか。**
12. **効果ツリーの走査は必ず `children()` で再帰する**（`KeywordScan`、バリデータ、インテント集計で共通）。
13. **テキストは必ず翻訳キーを通す。**
14. **Hook のソートは必ず安定ソート。**

---

## 22. 命名とコーディング規約

- ファイル名は `snake_case.gd` / `.tscn` / `.tres`。`class_name` は `PascalCase`。関数と変数は `snake_case`。定数と列挙値は `UPPER_SNAKE_CASE`。プライベートメンバは `_` で始める。id は `StringName`（`&"strike"`）。
- 全面的に静的型付け（`var hp: int`、`-> void`、`Array[Card]`、`Dictionary[StringName, CardData]`）。プロジェクト設定で `untyped_declaration` と `unsafe_*` の警告を有効にする。
- 各クラスの先頭に `##` のドキュメントコメントで責務と所属レイヤーを書く。「なぜこうしたか」という重要な判断はその場に書く。
- 1 ファイルに主要クラス 1 つ。約 400 行を超えたら分割を検討する（例：`Combat` のターンの流れを `turn_flow.gd` に分ける）。
- signal 名は過去形（`finished`、`phase_changed`、`card_hovered`）。ハンドラ関数は `_on_<発信元>_<signal>`。
- `_process` でルールの計算をしない。表現層が毎フレーム行うのは補間と再生だけ。

---

## 23. 協力プレイ（LAN）：ロックステップ

> 2026-10-23 追加。ルールは `GameDesign.md` §21。

### 23.1 方式の選択

- **ホストが順番を決めるコマンドのロックステップ**。全員の PC が同じ `RunController` / `Combat` を持ち、同じ順番で同じコマンドを実行する。ルール層は決定的（名前付きの乱数ストリーム、§11）なので、同じシード + 同じコマンド列 = 同じ状態になる。
- 「ホストだけが計算してイベントを配る」方式は採らなかった：表現層がモデル（手札・カードの数値・インテント・ショップ）を直接読むので、参加者側にモデルの写しを作り直す必要があり、改修が大きすぎるため。
- 通信量はコマンド 1 つ数百バイトで、LAN なら遅延は数 ms。

### 23.2 層ごとの分担

| 層 | クラス | 役割 |
|---|---|---|
| ③ Domain | `PlayerSeat`（戦闘の席）、`PlayerState`（ランのプレイヤー） | プレイヤーごとの持ち物。1 人プレイでは 1 つだけ |
| ③ Domain | `Combat.seat` / `RunState.active` | 「いま処理している人」。`player` / `piles` / `turn` / `potions` / `relics`（戦闘）、`hp` / `gold` / `deck` …（ラン）はこの人のものを返す。効果・Behavior・RunEffect は席を意識しない |
| ④ Flow | `CombatController` / `RunController` | コマンドとクエリに最後の引数 `seat` / `who`（-1 = いまの人）。コマンドが処理する人を切り替える |
| ④ Flow | `CoopCommands` | 送る形 `{seq, seat, op, args}`（カード・ユニットは uid）。`apply(run, cmd)` と、ずれ検出用の `digest(run)`。純粋なのでテストで 2 つの RunController に同じ列を流せる |
| ① Platform | `Net`（Autoload、`net_session.gd`） | ENet の接続・ロビー・LAN の自動検出（UDP ブロードキャスト）・コマンドの順番付けと配信 |
| ⑤ Presentation | `Party` | 画面の操作の窓口。1 人プレイはその場で `CoopCommands.apply`（同期）、協力プレイは `Net.submit`（返事で `on_done(ok)`）。表示に使う「自分」（`Party.me(run)` / `CombatScreen.me()`）もここで引く |
| ⑤ Presentation | `LobbyScreen` | ホスト / 参加 / 席の一覧 / 開始 |

**表現層は `Combat.seat` / `RunState.active` を当てにしない**（それはルール側の処理用で、ほかの人のコマンドを処理すると変わる）。自分の値は必ず `Party` / `CombatScreen.me()` から読む。クエリに席を渡す（`ctl.card_text(card, target, kw, seat)` など）と、Controller が一時的に切り替えて元に戻す。

### 23.3 戦闘（席）

- `Combat.seats`：席ごとに `Piles`・`TurnState`（エネルギーとプレイ統計。フェーズとターン数は全席で同じ値）・ポーション・レリック・`ready`。プレイヤーのユニットの uid は席 0 が 0、それ以外は 100 + 席（敵は 1〜）。
- **処理の席の切り替え（focus）**：コマンドは指定の席、ターンの手順は席ごとに、キューの処理は現場から（`ResolveEffectAction` = 発動者 / 敵の行動なら狙われたプレイヤー、`TriggerCardAction` = 積んだときの席、`_finish_play` = 出した席）。決定性のため、ルールのコードで「たまたま今の席」を使わない（敵 AI は `lead_player()` = 席の順で最初の生存者）。
- **HookDispatcher**：席ごとの Hook（カードのプレイ・コスト・行き先・ドロー、ターンのエネルギー / ドロー）は、いまの席のプレイヤーのステータスとレリックだけ。それ以外の Hook は全席のレリックを集める（Behavior は `host.owner` で自分のことか判定する）。
- **ターン**：開始は席の順にブロック・エネルギー・`TURN_STARTED`・ドロー。`end_turn` は Ready、全員（生存者）が Ready で `end_player_turn`。`cancel_ready` で取り消し。カード選択待ち（`pending_choice`）は 1 つだけで、その間はほかの人も操作できない（キューが空でないため。選択は短いので待たせる）。
- **敵の行動**（`CombatTurnFlow._push_move`）：プレイヤーを狙う効果（`ChosenTarget`、対象なしで山に触れる効果。`children()` で辿る）は生存者全員に 1 回ずつ、それ以外は 1 回。並び順は保つ。1 人プレイでは従来と同じ 1 つの現場。
- 倒れた人は Ready 扱い。全員が倒れたら敗北。結果は `result_for(seat)`（`downed`）。

### 23.4 ラン

- `RunState.players`。`RunController` のコマンドは `who` で人を切り替える（`use_player`）。クエリ（`event_option_available`）は切り替えて元に戻す。
- `vote(node, who)`：全員の投票で `enter_node`。`leave_node(who)` / `advance_act(who)`：その人の `done`、全員そろったら進む。`cancel_leave`。変化は `party_changed`。
- ショップ・宝箱・戦闘報酬は席の順に人数分作る（乱数の消費順が全員で同じ）。
- デッキのカードの uid は人ごとに `PlayerState.UID_STRIDE`（100000）ずつずらす（戦闘で全員のカードが同じ場に出ても重ならない）。
- セーブ：プレイヤー 0 は従来どおり最上位、2 人目以降は `coop_players`（1 人プレイのセーブの形は変わらない）。

### 23.5 通信（Net）

```
参加者 A           ホスト                      参加者 B
submit(op) ──rpc──▶ CoopCommands.apply(run)
                    受け付けた → seq, hash を付けて
◀────── rpc ─────── _rpc_command(cmd) ──────rpc──▶
apply(run)          （自分の操作ならその場で）      apply(run)
digest を比べる                                    digest を比べる
```

- ポート：ENet 24600（UDP）、自動検出 24601（UDP ブロードキャスト、1 秒ごと）。ホストの PC は初回に Windows ファイアウォールの許可が必要。
- 断られたコマンド（ほかの人の操作が先・状態が変わった）は配らず、出した人に `on_done(false)`。
- `digest` が合わなければ `desync_detected`（Main が案内を出す）。番号の飛びも同じ。
- 抜けた人がいたらセッション終了（ホストのセーブから再開）。

### 23.6 テスト

- `tests/unit/combat/test_coop_combat.gd`：席・Ready・敵の攻撃は全員・HP の人数補正・倒れた人・カード選択の持ち主・同じコマンドで同じ状態。
- `tests/unit/run/test_coop_run.gd`：投票・各自の報酬 / ショップ / 休憩 / イベント・全員の「進む」・復活・セーブ・2 つの RunController の一致。
- `tests/unit/net/test_net_session.gd`：1 つのプロセスで 2 台分の Net（別の SceneMultiplayer の枝）を本物の ENet でつなぐ。ロビー・開始・投票 → 戦闘 → カード → Ready で digest が一致・断られたコマンド・切断・版違い。
- スモークテスト（skill trycard-dev の `coop_smoke.ps1`）：本物の Main を 2 つのプロセスで起動し、UiBot がホストと参加者として 1 ランを最後まで遊ぶ。


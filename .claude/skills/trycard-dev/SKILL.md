---
name: trycard-dev
description: TryCard（Godot 4.7.2 / GDScript の Slay the Spire 風ゲーム、D:\GodotDev\SlayTheSpire3）の開発作業の手順と落とし穴。テストの実行、コンテンツ .tres の生成・インデックス再構築・検証、ヘッドレスでのエディタ / ゲームの起動確認、新しいブロックやコンテンツの追加をするときに使う。画面（Screen / CombatScreen / モーダル）の追加や修正、スクリーンショットでの見た目の確認にも使う。戦闘の 3D キャラクター（KayKit モデル・アニメーションの取り込み、敵の見た目の追加、攻撃モーションとダメージ表示の同期）、ツールチップ・ショップ・アップグレードの比較・再起動からの再開（M5）、パーティクルのエフェクト（被弾・ブロック・状態異常・回復・カード使用・登場・死亡・勝利）の追加や調整にも使う。報酬画面・カードの 3 択（RewardScreen / CardShowcase）にも使う。協力プレイ（LAN の 2〜4 人、ENet のロックステップ、ロビー、席・Ready・投票、同期ずれ、2 プロセスのスモークテスト）にも使う。Triggers on: 協力プレイ, マルチプレイ, co-op, multiplayer, Net, ENet, ロビー, LobbyScreen, Party, CoopCommands, PlayerSeat, PlayerState, 同期ずれ, desync, coop_smoke, icon_sheet, アイコン, 意図のアイコン, レリックの絵, ポーションの絵, 状態異常のアイコン, マゼンタ, RewardScreen, CardShowcase, RewardRow, 戦利品, 報酬画面, CardView, カード面, カードフレーム, card_frames, パーティクル, エフェクト, GPUParticles, StageEffect, CardBurst, spawn_fx, Fx, Tooltip, TooltipPanel, CardTips, ShopScreen, upgrade_preview, test_ui_restart, run_tests, seed_content, content_library, ContentValidator, GUT, TryCard, M2, M3, M4, M4.5, M5, RunController, CombatScreen, CombatPresenter, UiBot, BattleStage, StageActor, StageDirector, ActorCatalog, KayKit, 3D モデル, アニメーション, スクリーンショット, 画面追加, セーブ, マップ生成, カード追加, ブロック追加, 敵追加.
---

# TryCard 開発手順

設計の正は `GameDesign.md`（ルール / 付録 C = 決定事項）、`Architecture.md`（構造 / §19.5〜19.8 = 実装メモ）、`DevelopmentPlan.md`（マイルストーンと状態）。設計書に無いルールに出会ったら自分で決めずにユーザーに聞く。

## コマンド（PowerShell）

```powershell
$g = "D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"; $p = "D:\GodotDev\SlayTheSpire3"
# 普段：変更に関係するテストファイルだけ（ファイル名の部分一致、カンマ区切り。出力は失敗・警告と合計 1 行だけ）
powershell -NoProfile -ExecutionPolicy Bypass -File $p\tools\run_tests.ps1 -SkipImport -Select test_shop,test_tooltip
# 全テスト（インポート込み。終了コード 0 = 成功）：マイルストーン完了時・大きな変更の前・ユーザーが頼んだ時だけ
powershell -NoProfile -ExecutionPolicy Bypass -File $p\tools\run_tests.ps1        # -SkipImport で高速化、-Full で全ログ
# コンテンツを付録 A から作り直す（content/ を消す。Inspector での編集は失われる）
& $g --headless --path $p -s tools/seed_content.gd -- --force
# ゲーム / エディタ（プラグイン込み）がエラーなしで起動するか
& $g --headless --path $p --quit-after 120
& $g --headless --path $p --editor --quit-after 200
```

## 変更後の確認の順番
1. `--import`（新しい class_name / リソースを足したときだけ。run_tests.ps1 は -SkipImport なしなら自動で行う）→ 2. `run_tests.ps1 -Select <関係するテスト>`（全件は節目だけ。トークン節約のためユーザーが指定）→ 3. `leaked` / `still in use` / `SCRIPT ERROR` は既定の出力に自動で出る（テストが緑でも出る）。返答にテストログを貼らず、合計行だけ伝える。

## 落とし穴（実測済み）
- `--check-only --script` は Autoload を読まないので `Identifier not found: TimeFx` などが出るが誤検出。コンパイル確認は `tests/unit/test_scripts_compile.gd` に任せる。
- `tools/*.ps1` は ASCII のみで書く（Windows PowerShell 5.1 は BOM なしを ANSI で読む）。
- `ResourceSaver.save(..., FLAG_CHANGE_PATH)` では参照が ext_resource にならず埋め込みになった。保存後に `res.take_over_path(path)` する。
- テストで RefCounted の循環参照（例：アップグレードの循環）を作ったら最後に切る。切らないと終了時に `ObjectDB instances were leaked`。
- エディタ上では `@tool` でないスクリプトのメソッドは動かない（placeholder）。プラグインから使うコード（`addons/trycard_tools/`）はメソッドを呼ばず、エクスポートされたプロパティを読む。
- `Control.show()` と衝突するので画面切り替えは `ScreenHost.show_screen()`。
- GUT は `push_error` とエンジンのエラーをテスト失敗として扱う（`.gutconfig.json` の既定）。
- `tests/` の下で `test_` で始まるファイルは GUT がテストと見なす。支援クラスは別の名前にする（例：`content_kit.gd`）。
- テストで `const T := SomeClass` は「定数式でない」エラー。`const T = preload("res://...gd")` にする。
- `wrap` / `seed` / `hash` など組み込み関数と同じ名前のメソッドは呼び出しが組み込み側に解決される。避ける。
- `class_name` 付きクラスの静的関数を `reload` / `new` / `get_path` など `GDScript`（Script）のメソッドと同じ名前にすると、`Klass.reload(x)` がスクリプト自身のメソッドに解決されて「引数の数が違う」エラーになる（実測：`RunFixtures.reload` → `reload_state` に改名）。
- 循環参照の中では列挙型の引数の型（`p: Combatant.Side`）が解決できないことがある。int で受けて `as` で変換する。
- RefCounted の循環参照はリークになる（GUT 終了時の `ObjectDB instances were leaked`）。逆向きの参照は WeakRef、キューに積む Callable はラムダではなく `method.bind()`。
- `load()` はコンパイルに失敗したスクリプトでも非 null を返す。コンパイル確認は `can_instantiate() or is_abstract()`。
- シミュレーションの戦闘数は環境変数 `TRYCARD_SIM_COMBATS`（既定 1000、約 17 秒）。

## 戦闘エンジン（M2）の要点
- 外部からは `CombatController` だけを使う（`begin(setup)`、`play_card`、`end_turn`、`submit_choice`、`intent_of`、`card_text`）。
- テストは `CombatBuilder`（`with_hand` / `with_enemy` / `with_relic` …）→ `CombatHarness`（`play(&"id")`、`end_turn()`、`choose([...])`、`events_of()`、`cards_conserved()`）。ルールのテスト用の部品は `ContentKit`。
- 不変条件の検査をわざと壊して確かめるときは、ファイルを一時的に書き換えて sim だけを回す：`-gdir=res://tests/sim`。終わったら必ず元に戻す。

## ラン進行（M3）の要点
- 外部からは `RunController` だけを使う。フェーズは `state.phase`、通知は `phase_changed` / `checkpoint_reached(reason)` / `combat_started(ctl)`。戦闘が終わったら `acknowledge_combat_end()`、ノードを離れるのは `leave_node()` だけ。
- チェックポイントは 4 種類（`CP_NODE_ENTERED` / `CP_COMBAT_STARTED` / `CP_REWARD_GENERATED` / `CP_RETURNED_TO_MAP`）。チェックポイントの後に乱数を使って状態を変える処理は、必ず `resume()` で同じことをやり直せる位置に置く（そうしないと再開の一致テストが落ちる）。
- テストは `RunFixtures`（`new_run` / `force_next(run, type, id)` でノードの種類を書き換え / `win_combat` / `reload_state` / `dump`）、`RunBot`、`RunRecorder`（全チェックポイントの記録と再開）。複数アクトは `RunFixtures.multi_act_library(lib, 3)`（正式コンテンツは 1 アクト）。
- run の signal に「run を捕まえるラムダ」をつなぐと循環参照になる。テストの最後に `disconnect` する。
- シミュレーションのラン数は環境変数 `TRYCARD_SIM_RUNS`（既定 200、約 27 秒）。sim だけ回す：`& $g --headless --path $p -s addons/gut/gut_cmdln.gd -gdir=res://tests/sim -gexit`。
- 再開の検査をわざと壊して確かめる例：`enter_node` の `_checkpoint(CP_NODE_ENTERED)` を `handler.enter()` の後ろへ移す → `test_run_resume.gd` が落ちる。終わったら必ず元に戻す。
- `SaveManager` はテストでは `preload("res://src/platform/save_manager.gd").new()` して `run_path` を `user://test_saves/...` に差し替える（Autoload の本物を触らない）。

## ルール（門番テストが検査する）
- `src/content` `src/domain` `src/flow` では Node 継承・`get_tree`・`await`・グローバル乱数（`randi()` / 引数なし `.shuffle()`）・ファイル I/O（`load(` も）・`Time.` / `OS.` / `Engine.`・Autoload 参照が禁止。
- ブロック（効果 / 値 / 条件 / 対象 / Behavior / AI / RunEffect / RunCondition）はエクスポートしないメンバ変数を持てない（バリデータが検査）。

## コンテンツの追加
- 既存のブロックで作れるなら `.tres` を作るだけ。保存するとプラグインがインデックスを再構築する（ヘッドレスなら seed をやり直すか `ContentIndexBuilder.rebuild()`）。
- カードの `text` の `{label}` は効果の `label` と 1 対 1（未使用の label もエラー）。`ChosenTarget` を使うなら `aim = ENEMY`。
- 数を変えたら `tests/unit/content/test_content_library.gd` の期待値と `GameDesign.md` 付録 A.3 を同時に直す。
- 新しいブロックの必須フィールドは `ContentValidator.REQUIRED` に追加する。

## 画面（M4）の要点
- 画面は `Screen`（`run` と `modals` を持つ）。ランの操作は `run` のコマンド、遷移は `run.phase_changed` を受けた Main だけ。フェーズ → 画面は `main.tscn` の `screens`。簡素な画面は `PanelScreen` を継承してコードで並べる。
- 戦闘画面：`CombatPresenter` がイベントを再生（開戦からの `Combat.events` も再生する）→ 再生が終わると `CombatScreen.sync_from_model()`。入力のロックは 2 段：カードを出すのは `can_play()`（再生中でもプレイヤーのターンを見せていれば可。`try_play` が `presenter.catch_up()` で残りの演出を一度に見せてから出す）、ターン終了・ポーションは `can_act()`（= 再生が終わっている + `can_play()`）。テストでは `screen.presenter.instant = true`。
- カード選択 / 閲覧は `CardListModal` 1 つ（`choose(indices)` がクリックと同じ経路）。テストで画面を操作するときは画面の公開メソッド（`MapScreen.choose_node`、`RewardScreen.take`、`CombatScreen.try_play` …）を呼ぶ。ランの完走は `UiBot`（`tests/sim/test_ui_runs.gd`、`TRYCARD_UI_RUNS`）。
- Main を使うテストは `SaveManager.run_path` を `user://test_saves/...` に差し替え、after_each で戻す（本物のセーブを消さない）。

## 見た目の確認（スクリーンショット）
- **撮るのは必要なときだけ（トークン節約のためユーザーが指定）**：見た目を変えた（レイアウト・色・フレーム・エフェクトなど）とき、またはユーザーが頼んだときだけ。ロジック・数値・テストだけの変更では撮らない。撮っても Read で見るのは変更に関係する 1〜2 枚だけ（22 枚を全部は見ない）。
- 描画ありで起動して撮る：`& $g --path $p -s $p\.claude\skills\trycard-dev\scripts\capture_screens.gd -- <出力先フォルダ>`（22 枚：メニュー → マップ → 戦闘の各場面とツールチップ → 報酬 → カード選択（ホバー・スキップ後）→ ショップ → イベント → 休憩 → アップグレードの比較。撮る場面を変えるときは `scripts/capture_impl.gd` を直す）。撮影は `root.get_texture().get_image().save_png(path)`（`await RenderingServer.frame_post_draw` の後）。ウィンドウが開くので `Start-Process ... -PassThru` ＋ `WaitForExit(秒)` でタイムアウトを付ける。
- **`-s` のスクリプトから `UiText` や画面のクラスを静的に参照しない**。Autoload（`Content` / `Fx`）の登録前にコンパイルされ、参照先が壊れる（`Nonexistent function 'xxx' in base 'GDScript'`、`root of ... is not a Screen`）。起動用スクリプトは `_initialize` で `call_deferred` し、本体は別ファイルを `load()` して実行する。
- ツールチップを撮る：`capture_impl.gd` の `_hover(control)` が `InputEventMouseMotion` を `root.push_input(ev, true)` で送る（本物のカーソルは動かさない。位置は `control.get_global_transform_with_canvas() * (size / 2)`）。40 フレーム待てば出る。カードの用語は `CardView.show_tips()` を直接呼ぶ。
- 撮影スクリプトは `res://` の下の普通のフォルダに置かない（`.claude/` は隠しフォルダなので Godot は取り込まない）。出力先は scratchpad にする。

## 3D の戦闘キャラクター（M4.5。Architecture §14.6 / §19.9）
- 構成：`src/presentation/stage/`（`BattleStage` = Field の一番下の透明 SubViewport、`StageActor` = 1 体、`StageDirector` = イベント → 動作、`ActorCatalog` = 見た目の表）。2D のレイアウトが正（足元 = `UnitView.portrait_rect()` の下辺中央）なので、照準・テストは 3D を知らない。
- **敵を追加したら `ActorCatalog.ENEMIES` にも追加**（無いと図形の立ち絵になる）。`test_stage.gd` が全敵の表と、参照する素材・クリップの実在を検査する。
- 新しいモデル / アニメーションの取り込み：
  - アニメーションの glb は `.import` を `[remap]\nimporter="animation_library"\ntype="AnimationLibrary"` だけ書いて `--import` すると AnimationLibrary になる（Godot が残りを埋める）。
  - クリップ名・骨・メッシュ・高さは `python -I scripts/glbinfo.py <glb...>` で Godot を使わずに読める。KayKit は Rig_Medium / Rig_Large ともに骨 23 本・同名なので、トラックのパス `Rig_Medium/Skeleton3D:骨` がキャラの glb にそのまま合う。Rig_Large のキャラ（Golem など）には Rig_Large のライブラリが要る。
  - KayKit のキャラのパック（無料版も SOURCE 版も）の General には**攻撃のモーションが無い**。戦闘モーションは別パックの KayKit Character Animations（CombatMelee / CombatRanged / Special / Simulation）。
  - 当たる瞬間（`ActorCatalog.IMPACT`）は「手の骨の速さが最大の時刻」を測って決めた。ヘッドレスで `ap.seek()` しても `get_bone_global_pose` は更新されないので、Animation の `position_track_interpolate` / `rotation_track_interpolate` で骨の連鎖を自前で合成して測る。
- 動きの確認：`& $g --path $p -s $p\.claude\skills\trycard-dev\scripts\capture_stage.gd -- <出力先> <encounter id...>`（攻撃と敵のターンを連続で撮る。`Start-Process` ＋ タイムアウト）。枚数が多いので `python -I scripts/sheet.py <出力先> "<glob>" <一覧.png> <列数>` で戦場の部分を一覧画像にしてから見る（PIL）。
- 照準の見た目：`UnitView.set_targeted` → `targeted_changed` を `BattleStage`（3D の輪郭線）と `TargetRings`（足元の楕円。Field の舞台の下）が受ける。2D の枠は無い。輪郭線は `assets/shaders/target_outline.gdshader`：StandardMaterial3D の `grow` だと KayKit の別パーツ（腕・顔）の殻が体の手前に出て内側に白線が出たので、ビュー空間で xy に広げて z を奥へ押す自作シェーダーにした。被弾の光と輪郭線は `material_overlay` 1 枠を `next_pass` でつなぐ。
- カーソルを `display/mouse_cursor/custom_image` で指定すると、終了時に `Texture ... leaked` / `RenderingServer::get_singleton() is null` が出た。`Main` で `Input.set_custom_mouse_cursor` し、`_exit_tree` で null に戻す。
- `SubViewportContainer` の大きさが 0 のフレームで `Camera3D.size` に 0 を入れるとエンジンのエラー（GUT で失敗扱い）。`BattleStage._process` で弾いている。

## エフェクト（パーティクル。M6 の一部を前倒し。Architecture §19.11）
- 2 系統：キャラに付く 3D（`BattleStage.EFFECTS`：hit / guard / block / death / shatter / heal / poison / poison_tick / strength / weak / vulnerable / spawn）は `BattleStage.spawn_fx(kind, at, facing, size)`（位置固定）か `spawn_on(kind, actor, 身長の割合)`（身長に合わせた大きさで、アクターに付いていく）→ `scenes/fx/stage/*.tscn`（根 = `StageEffect`、子 = one_shot の GPUParticles3D）。UI の 2D（`card_burst` / `victory`）は `Fx.spawn` のプール → `scenes/fx/*.tscn`（`ParticleFx`。画面全体に出すものは `_place()` を上書き：`VictoryFx`）。どれを出すかは `StageDirector.after`（状態異常は `STATUS_FX` の表）と `CombatPresenter._play`。
- **落とし穴（実測）**：ParticleProcessMaterial の turbulence は速度をノイズの流れへ引き寄せるので、弱い影響（0.05〜0.15）でも打ち上げの初速が消える（紙吹雪が角から動かなかった）。速く飛ばす粒には使わない（ゆっくり漂う魂などだけ）。
- 新しい 3D エフェクト：既存の `.tscn` を複製して見た目を変え、`BattleStage.EFFECTS` に足す（`test_stage_effects_play_once_and_free` が one_shot・止まっている・local_coords を検査）。子の GPUParticles3D は `local_coords = true`（でないと根の scale が粒の大きさに効かない）。
- テクスチャは `tools/fx_textures.py`（PIL）が作る白 + アルファの図形（`assets/textures/fx/`）。色は `color_ramp`（頂点カラー）で付けるので、3D の材質は `vertex_color_use_as_albedo = true` が必須。
- **落とし穴（実測）**：透明な SubViewport に半透明を描くと、色が乗算済みのまま残り、普通に重ねると暗く濁る（リングが茶色になった）。`BattleStage` の材質を `CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA` にしてある。3D のエフェクトの材質は加算（Add）にしない（透明な所に出ない）。2D（Fx の CanvasLayer）は加算でよい。
- 初めて出すときのカクつき対策：`BattleStage._warm_up` が全種類を大きさ 0.001 で 1 回出してシェーダーをコンパイルさせる。
- 試し撃ち：`& $g --path $p --fixed-fps 60 -s $p\.claude\skills\trycard-dev\scripts\capture_fx.gd -- <出力先> [kind...]`（ゲームを通さず、戦闘と同じカメラで横に並べて 4 フレームおきに 18 枚。`Fx.SCENES` の 2D の名前も指定できる）。ゲーム内は `capture_stage.gd`（撃破と勝利の場面も撮る）。**どちらも `--fixed-fps 60` を付ける**：撮影が遅いので、付けないと 1 枚の間に 0.3 秒以上進んでエフェクトがほぼ写らない。
- テストで「ノードが消えたか」をラムダで待つときは、ノードを直接捕まえず `var ref: WeakRef = weakref(node)` を捕まえる（解放済みの捕捉はエンジンのエラー = GUT で失敗）。`var ref := weakref(...)` は Variant からの推論でパースエラーになり、**そのテストファイルが丸ごと読み込まれずに終了コード 0** になる（テスト数が減ったら疑う）。

## 落とし穴（M4 で実測）
- フェードなど「止めたノードを動かす」Tween は、止めたノード自身ではなく動いている側（host）で `create_tween()` する。止めたノードの Tween は進まず、`tween_callback(queue_free)` も呼ばれない（ScreenHost の実例。テストはフェード 0 秒で見逃していた）。
- 警告がエラー扱い：`var x := dict.get(...)` / 三項演算子の片側が Variant だと「Variant から型推論」でパースエラーになる。`var x: String = ...` と型を書く。
- GUT の `Orphans` は `remove_child` ＋ `queue_free` の解放待ちでも出る。画面のテストは after_each で `await wait_process_frames(2)` してから判断する（本当のリークは終了時の `ObjectDB instances were leaked`）。
- `Control.global_position` はスケールの影響を受けない（pivot が中心なら中心は `global_position + size / 2`）。
- `pivot_offset` を使うカード（`CardView`）をコンテナ内で縮小表示するときは、`pivot_offset = 0` にしてから `scale` を掛け、外側の Control に縮小後の大きさを `custom_minimum_size` で与える。

## 画面（M5）の要点
- ツールチップは `TooltipPanel`。一般の Control は `tooltip_text`（1 行目 = 見出し、2 行目以降 = 本文 BBCode）を入れ、`GlyphBadge` / `TipButton` の `_make_custom_tooltip` が `TooltipPanel.for_tooltip()` を返す。ボタンを足すときは `Button` ではなく `TipButton`（`PanelScreen.add_button` は TipButton）。カードは `CardView` のホバーで `CardTips`（CanvasLayer 100）が横に並ぶ（`tips_enabled` で止める）。
- **落とし穴（実測）**：`_make_custom_tooltip` の戻り値は Godot が自前のポップアップ（テーマの `TooltipPanel` の枠）に入れる。自分でも枠を描くと二重になり、`RichTextLabel.fit_content` / 自動折り返しの高さはポップアップの大きさを決めた後に決まるので、文字の切れた小さな空の枠になった。枠は描かず（`for_tooltip`）、本文の大きさはフォントで先に測って `custom_minimum_size` に入れる（`TooltipPanel.body_size`）。
- アップグレードの選択は `open_card_list({..., upgrade_preview = true})`（1 枚選びのときだけ）。比較の操作は `open_compare(i)` / `confirm_compare()` / `close_compare()`、`cancel()` は比較中なら一覧に戻る。
- ショップは `ShopScreen.offer_views` / `price_labels`（商品の番号 → 表示）。商品のクリックは `CardView.pressed` / バッジの `gui_input` → `buy(i)`。
- 複数アクトの画面（アクト移行）を Main で通すときは `main.content_override = RunFixtures.short_library(Content.library, 2, 3)` ＋ `tough_config`、`UiBot.step()` を `ActTransitionScreen` が出るまで回す。
- 再起動からの再開：`tests/sim/test_ui_restart.gd`（全チェックポイントのセーブファイルから新しい Main で「続きから」、直後の画面と状態が一致）。`TRYCARD_RESTART_RUNS`（既定 2、約 26 秒）。単体で回す：`-gdir=res://tests/sim -gselect=test_ui_restart`。
- **落とし穴（実測）**：Windows で書いた直後のファイルの `DirAccess.rename_absolute` がまれに `Failed` になる（ほかのプロセスが一瞬開いている）。`SaveManager._retry()` でやり直している。セーブの書き方を変えるときもファイル操作は `_retry` を通す。全体のテストの中でだけ落ちる（単体では通る）ときはこれを疑う。

## ターンの切り替え演出（StS2 の録画を 30fps で測って合わせた。2026-10-20）
- イベント：`TURN_ENDING`（`end_player_turn` の先頭 = 押した瞬間）→ 手札の後始末 → `TURN_ENDED` → 敵の行動。`TURN_STARTED` はドローより前。
- `CombatPresenter._play`：`TURN_STARTED` → `CombatScreen.show_player_turn(n)`、`TURN_ENDING` → `show_enemy_turn()`（入力のロックもここ）、`COMBAT_ENDED` → `show_combat_over()`。`TURN_ENDING`〜`TURN_ENDED` の捨て札は `HandView.release(..., &"burn")`（焦げて縮み、`EmberTrail` の炎の尾を引いて 2 次ベジェの弧で山へ）。
- `TurnBanner`（combat.tscn の `Banner`。Field の上・手札の下）：あなたのターン = 浮き上がり + サブタイトル、敵のターン = 1.85 倍から縮む → 1.4 秒で金から赤 → 消える。進行も入力も止めない。倍率は `set_speed(presenter.current_speed())`。フォントは `assets/fonts/banner_mincho.ttf`（Shippori Mincho B1 を `tools/banner_font.py` で使う文字だけに絞った。バナーの文言に漢字を足したら `KANJI` に足して作り直す）。
- ターン終了ボタンは 0.55 秒遅れて下から出る（TRANS_BACK）、押すと下へ引っ込む。エネルギーのオーブは敵のターンで暗くなる。タイミングは `CombatPacing`（TURN_ENDED 0.95 秒 = 押してから約 1.5 秒で敵が動く）。
- 炎の尾の強さはユーザーと調整済み（30px・16 点・明るい加算 = 光りすぎ、13px・9 点・通常合成 = 地味すぎ → 18px・12 点・色を抑えた加算）。
- 撮る：`& $g --path $p --fixed-fps 30 -s $p\.claude\skills\trycard-dev\scripts\capture_turns.gd -- <出力先> [encounter]`（開戦から start_NN、ターン終了から end_NN を毎フレーム。録画の連番と同じ刻み）。
- **落とし穴（実測）**：`CardView` の見た目の中心は `position + size / 2` と一致しないことがある（縮めたチップと炎の尾がずれた）。回転・縮小込みの中心は `get_global_transform() * (size / 2)`（`HandView.visual_center`）。

## 戦闘背景の環境エフェクト（光の筋＋塵・地面の霧・ホタル）
- 背景は `CombatScreen.BACKDROPS` = `BackdropData` の `.tres`（`assets/textures/backgrounds/battle_forest_ruins_N.tres`。`content/` は seed --force で消えるので置かない）。画像と Light / Mist / Fireflies の値を持つ。
- `BattleAmbience`（combat.tscn の `Ambience`：Mist → Rays → Fireflies、どれも全画面 ColorRect のシェーダー）が Backdrop と Field の間、手前のホタル `AmbienceFront` は Field と UI の間（手札の範囲は `y_bottom` で消す）。値が 0 / 無効のものは非表示（描画しない）。
- シェーダー：`god_rays.gdshader`（加算。塵は筋の中だけ光る）、`ground_mist.gdshader`（通常合成）、`fireflies.gdshader`（加算。セルごとに 1 匹がさまよって点滅。奥と手前は同じシェーダーで値違い）。共通ノイズは `noise.gdshaderinc`。
- ホタルを GPUParticles2D にしなかった理由：2D では turbulence のノイズの大きさが px 座標と合わず扱いにくく、個体ごとの点滅もできないため。
- 撮る：`& $g --path $p --fixed-fps 60 -s $p\.claude\skills\trycard-dev\scripts\capture_backdrops.gd -- <出力先>`（背景ごとに off と on を 1 秒おきに。戦闘なしで combat.tscn を置く）。控えめな効果は PIL で off と on の差を 6 倍にすると位置が分かる。

## カード面（画像のフレーム。cardframe02）
- 構成：`scenes/widgets/card_view.tscn`。フレーム画像（`assets/textures/card_frames/frame_{bronze,silver,gold}.png`、1024x1440）の上に、各欄をフレームに対する**割合（anchor）**で置いている。`BASE_SIZE` は 300x420（手札は ×0.78）。欄の位置を変えるときは、1024x1440 の座標を割ってから anchor に入れる。
- フレームは `python -I tools/card_frames.py <cardframe02 のフォルダ>` で作り直す。内側の列（x 116〜908）だけを上へずらして絵の窓を 90 行縮め（窓 612x495 = 比 1.24。元は 180 行で比 1.51 だったが、正方形のイラストが 1/3 切れるので戻した。0 行 = ほぼ正方形にすると最長の説明が字 11 でも入らない）、名前の札を太くし、羊皮紙を伸ばしている。外側の柱と下の丸は触らない（側面の飾りが歪むため。金は飾りが内側へ張り出している）。加工の量を変えたら、`card_view.tscn` の anchor（ArtBox の下・TypeLabel・NameLabel・Desc の上）と `card_shine.gdshader` の `art_rect`・`card_sparkle.gdshader` の `window_rect` も合わせる。
- カードのイラスト：元の絵（正方形、`assets/AiGenerateCardArt/`。ファイル名の英小文字の部分 = カードの id、英字の無い名前は `tools/card_art.py` の `NAMES`）→ `python -I tools/card_art.py [フォルダ]`（既定 AiGenerateCardArt。2 回目以降の絵は `assets/aiArt02` のように別フォルダで届くので引数で渡す）が 512 四方に縮めて `assets/textures/card_art/<id>.png`（`.import` = ミップマップ + VRAM 圧縮）→ `& $g --headless --path $p -s tools/card_art.gd` が今ある `.tres` に `art` と `art_focus` を入れる（強化版 `_plus` も同じ絵。`seed_content` も `CardArt.apply` を呼ぶので作り直しても消えない）。窓は横長なので `CardView.art_region` が AtlasTexture で横幅いっぱい・上下は `art_focus`（0 = 上端、1 = 下端）の位置を切り出す。中央以外の位置は `tools/card_art.gd` の `FOCUS` に書く（剣先や盾の下端が切れる絵だけ）。決めるときは窓の比で 0 / 0.5 / 1 の枠を重ねた一覧を PIL で作って見る。
- 金属の色 = レアリティ（`UiGlyphs.RARITY_FRAMES`。初期・コモン・SPECIAL = 銅、アンコモン = 銀、レア = 金）。**アップグレード版のデータは SPECIAL**（報酬の候補に出さないため。`seed_content._with_upgrade`）なので、フレームは `UiText.frame_rarity()` で基本版のレアリティを引く。
- 下の丸 2 つ = 種類の記号と色（`UiGlyphs.CARD_TYPE_COLORS`）。
- コストの丸（`CostOrb`）：cardframe02 の `energy_orb.png` の輪をフレームの色にした `cost_orb_{bronze,silver,gold}.png`（`python -I tools/cost_orbs.py <cardframe02>`。フレームの左上のコインの輪の色の分布に明るさの順位で合わせる。フレームを作り直したら作り直す）。表はレアリティ → `UiGlyphs.RARITY_COST_ORBS`。コストの無いカードは非表示。
- きらめき（`Sparkle`、`card_sparkle.gdshader`、Frame の直後・文字の前、加算）：`UiGlyphs.RARITY_SPARKLES`（銀 2〜3 = カードの id で決まる、金 4）の枠がそれぞれ周期の 28% だけ光る。出る場所は外周の帯・絵の窓の縁・コインの輪 3 つ・爪・王冠（金のみ）で、シェーダーの uniform に UV / px で測ってある。`seed` はカードの instance id（無いと同じレアリティのカードが同時に同じ所で光る）。撮る：`capture_card_fx.gd` の `sparkle_NN.png` を PIL の `ImageChops.lighter` で重ねると出る場所の分布が分かる。
- 輪郭グロー（`Glow`、`assets/shaders/card_glow.gdshader`）：最背面の ColorRect（カードより四辺 24px 大きい。シェーダーの `margin` と一致させる）。フレームのアルファを 36 点で膨張 + ぼかしして外側だけ加算で描く。`set_playable` = 青白、`set_selected` = 金色（手札では `HandView.set_held` が付ける）。
- スイープ光（`Shine`、`card_shine.gdshader`）：最前面（`Back` の下）の TextureRect、`texture` = フレーム（アルファだけをマスクに使う。透明な絵の窓は `art_rect` = ArtBox の anchor で補う）。ホバー `SHINE_DELAY` 0.3 秒で 1 回、待機中に離れたら取り消し、流れ始めたら最後まで。フレームを差し替えたら `_shine.texture` と Glow の `frame_tex` も更新する（`_apply` で実施）。どちらの材質も `resource_local_to_scene = true`（無いと全カードが同時に光る）。ArtBox の anchor を変えたら `art_rect` も直す。
- 説明の字：18 から入りきるまで 11 まで縮め、短い説明は行数が増えない範囲で 21 まで大きくする（`CardView._fit_desc`）。羊皮紙が明るいので `CardText.COLOR_UP / DOWN` を `DESC_COLORS` で濃い色に置き換える。全カードが収まることは `test_widgets.test_every_card_text_fits_the_parchment` が検査する。
- 素材はテクスチャのミップマップあり（`.import` の `mipmaps/generate=true`）＋ `CardView.texture_filter = LINEAR_WITH_MIPMAPS`。縮小表示で縁がちらつくのを防ぐ。
- ゲーム内で全カードを確かめる：メインメニューの「デバッグ：全カードで開始」（デバッグビルドのみ表示）→ 初期デッキが全カード 1 枚ずつ（強化版は除く、状態異常・呪いは含む。`Main.all_cards_config`）。上部バーの「デッキ」で一覧。
- 全カードの面を一覧で撮る：`& $g --path $p -s $p\.claude\skills\trycard-dev\scripts\capture_cards.gd -- <出力先> [倍率]`（倍率 0.78 = 手札での見え方。21 枚ずつ cards_NN.png）。`Start-Process` ＋ タイムアウト。
- 手札の位置（`HandView.BASE_FROM_BOTTOM` = 116。ユーザーと調整済み）は、カードの上端（y≈800）が敵の足元の状態異常アイコン（`UnitView` の一番下、y 740〜784）にかからないように決めてある（下端は画面の外へ沈む）。`UnitView` は下寄せの VBox なので、HP の行の高さを変えたら `combat.tscn` の `PlayerView` / `EnemyRow` の `offset_bottom` も同じだけずらす（足元 = 立ち絵の下辺を動かさないため）。HP バーは 14px で、ブロックのバッジはバーの左端に重ねている（行の高さに入れない）。

## 戦闘報酬とカードの 3 択（StS2 に合わせた。2026-10-20。Architecture §19.12）
- ラン中の勝利は結果のパネルを出さず `VICTORY_HOLD` 後に自動で報酬へ。テスト・ボット・撮影で「勝利後に進む」を待つときは `screen.result_pending()` → `continue_after_result()`（`%ResultPanel` の visible を見ない。敗北のときだけ出る）。
- 戦闘 → 報酬では戦闘画面が `ScreenHost.backdrop` に残る（`Screen.enter_backdrop()`）。`main.current_screen()` は報酬画面。背景にしたい画面を増やすなら `Main.show_phase` の `keep` の条件を広げ、その画面に `enter_backdrop()` を書く。
- 報酬の行は `RewardScreen.rows`（項目の番号 → `RewardRow`）、矢印は `proceed_button`。操作は従来どおり `take(i)` / `leave()`。
- 数枚から 1 枚を選ぶパネルは `open_card_list({..., showcase = true})` で `CardListModal.showcase`（`CardShowcase`）になる。`choose()` は演出なしで即決定（クリックは消える演出の後に `choose`）。強化後の表示は `showcase.show_upgraded(true)`。
- 素材は `python -I tools/reward_ui.py`（仮。同じ名前の PNG で差し替え可）。リボン・ボタンの文字に漢字を足したら `tools/banner_font.py` の `KANJI` に足し、元のフォント（google/fonts の `ofl/shipporiminchob1/ShipporiMinchoB1-ExtraBold.ttf`）で作り直す。fonttools はユーザーの site-packages にあるので `-I` を付けずに `python tools/banner_font.py <ttf>`。
- 撮る：`capture_screens.gd` の `10_reward` / `11_card_pick`（1 枚目をレアに差し替えて放射光を写す）/ `11b_card_pick_hover` / `11c_reward_after_skip`。暗幕の暗さは見た目では分かりにくいので、PIL で背景の同じ範囲の平均の明るさを比べる（戦闘中 57 → 報酬 16）。

## 宝箱の部屋（StS2 に合わせた。2026-10-22。Architecture §19.12）
- 宝箱のマスの `RewardScreen.chest`（`TreasureChestView`）：`is_open` / `open(animate)` / `is_over_chest(p)`。`take(i)` は閉じていても受け取れる（中で `open(false)`）。
- 背景の絵を差し替えたら宝箱の輪郭 `CHEST_POLY` と中身の位置 `MOUTH`（絵の px）を測り直す。開いた絵（`treasure_vault_open.jpg`）は閉じた絵と同じ構図にする（PIL で宝箱の外の差の平均が小さいことを確かめる）：PIL で絵を切り出して 50px の格子と数値を描き、多角形を重ねた画像で確かめる。
- 撮る：`capture_screens.gd` の `15b_treasure` / `15c_treasure_hover` / `15d_treasure_open` / `15d2_treasure_fountain` / `15e_treasure_loot`（開く演出は `--fixed-fps 60` を付けて撮る）。

## イベント画面（StS2 に合わせた。2026-10-20。Architecture §19.12）
- 選択肢は `EventScreen.option_buttons`（`EventOptionButton` = PanelContainer。`title_text()` / `detail_text()` / `disabled`）。操作は従来どおり `choose(i)` / `open_request()` / `leave()`。
- イベントを足すとき：選択肢の `text` = 名前、`detail` = 効果（seed では「名前（効果）」と書けば分かれる）。効果の色付けの規則は `UiText.EVENT_DETAIL_COLORS`。見出しの漢字がフォントに無いと豆腐になるので、`python tools/banner_font.py <ttf>` を回し直す（イベントの title を自動で含める）。
- **落とし穴（実測）**：折り返しのある RichTextLabel を Button / 素の Control の子にして高さを合わせると、幅 0 のときの巨大な高さが残って帯が崩れた。大きさはコンテナ（PanelContainer / MarginContainer）に任せ、コンテナの中の動きは余白（theme constant）を tween する。作り直す画面で入場の Tween を持つなら、作り直す前に kill する（消した入れ物を触ってエラー）。
- 撮る：`capture_screens.gd` の `13_event` / `15_event_result`。

## 休憩所（StS2 に合わせた。2026-10-20。Architecture §19.12）
- タイルは `RestScreen.tiles`（`RestTile`。`title_text()` / `disabled`）、説明と結果は `desc_text()`、選んだ後は `proceed_button`（`ProceedArrow`、報酬画面と共用）。操作は `rest()` / `open_upgrade()` / `leave()`。
- 背景の絵を差し替えたら、焚き火の位置（絵の px の `FLAME_RECT` / `GLOW_RECT` / `EMBER_AT`）を測り直す。PIL で炎の辺りを切り出して見ると早い。タイルの絵は `python -I tools/rest_ui.py`（同じ名前の PNG で差し替え可）。
- 撮る：`capture_screens.gd` の `16_rest` / `16b_rest_hover` / `19_rest_done`。

## HUD（山のアイコン・上部バー。StS2 に合わせた。2026-10-20）
- 山札・捨て札・廃棄・上部バーのデッキは `PileButton`（`TipButton` に画像 ＋ 右下の赤い枚数バッジ。`count` に枚数、名前はツールチップ）。廃棄は捨て札の上に小さく、0 枚でも出す。カードの飛ぶ先は `pile_center()`（ボタンの中心）なので置き場所を変えてもそのまま合う。
- アイコンと上部バーの石の帯は仮の自作（`python -I tools/hud_icons.py` → `assets/textures/ui/hud/`。山は `card_back.png` を傾けて 3 枚重ね、捨て札 = 青、廃棄 = 紫灰に色を変える）。素材を見つけたら同じ名前の PNG を差し替えるだけでよい（`.import` は mipmaps あり）。
- 上部バー（`scenes/widgets/top_bar.tscn`、根は `Control` で mouse_filter = IGNORE）：帯 `Bar`（テーマ `PanelTopBar` = `bar.png` の StyleBoxTexture）にキャラ / HP（数字だけ、バー無し）/ ゴールド / ポーション枠 / 層 / デッキ / 設定（アイコンだけ・未実装）。レリックは帯の下 1 列（y 80〜124。画面の左上に置く物はこれより下へ。マップの凡例は 140 から）。
- 戦闘中もポーションは上部バー：`CombatScreen.enter` が `top_bar.lend_potions(操作, 選択)` で枠を借り、`exit` で `reclaim_potions()`。Main を通さない sandbox・テストでは `top_bar == null` で戦闘画面の自前の `%Potions` を使う。

## アイコン画像（意図・状態異常・レリック・ポーション。2026-10-21）
- 元は AI のシート（純マゼンタ背景の格子。プロンプトと並び順はユーザーの ItemList.md）。`python -I tools/icon_sheet.py <intents|status|potions|relics1|relics2> [画像]` が切り出して `assets/textures/icons/{intent,status,potion,relic}/<id>.png` に書く。画像を渡すと `assets/textures/icons/_source/<シート名>.jpg`（`.gdignore` 付き）に写すので、次からは画像なしで作り直せる。並び順は `SHEETS`。
- 背景の抜き方：`d = min(R,B) - G` が高い画素を外周からたどった範囲 + 純マゼンタを含む穴だけを抜き、マゼンタを混ぜ戻した色から取り除く（光のにじみは半透明で残り、黒い縁取りの内側の紫は消えない）。ガラス越しにマゼンタが見える物は `FILL_HOLES`（提灯 = 灯りの色で塗る）。攻撃＋防御の意図はシートに無いので、短剣と盾を合成している。
- 新しい PNG を取り込んだら、`.import` の `mipmaps/generate=true` にして `--import` をもう一度実行する。
- 引き方：意図は `UiGlyphs.INTENT_ICONS`。レリック・ポーション・状態異常は `UiGlyphs.relic_icon / potion_icon / status_icon`（データの `icon` があればそれを優先し、無ければフォルダからファイル名 = id で探す。どちらも無ければ図形 ＋ 文字のまま）。`test_widgets.test_every_relic_potion_status_and_intent_has_an_icon` が全種類の絵の有無を検査するので、コンテンツを足したらシートにも描き足す。
- 意図は StS 風：バッジは描かずに 92px のアイコンだけ（`IntentHolder` はコンテナではないので `UnitView._process` でアイコンを上下に揺らせる）。数字はアイコンの左下（`IntentLabel` はアイコンの子）。状態異常は 40px のアイコンで、層数は右下（`GlyphBadge.corner_text`）。

## ターン終了ボタン（StS2 の「End Turn」に合わせた。2026-10-21）
- 見た目はテーマの `ButtonEndTurn`。両端のとがった紺の札で、素材は `python -I tools/end_turn_button.py` が作る `assets/textures/ui/hud/end_turn_{normal,hover,pressed,disabled}.png`。とがった両端は伸ばさない（StyleBoxTexture の左右の余白 42）。
- **落とし穴（実測）**：アンカーで置いた Control の `position.y` を Tween で動かすと `offset_top` も書き換わる。定位置を毎回 `offset_top` から計算していたせいで、ボタンが 1 ターンに 140px ずつ下へずれて消えていた。定位置は `enter()` で `_end_turn_home_offset` に 1 回だけ覚える（`test_screens` が 2 ターン目の位置を検査する）。

## Windows の exe を書き出す（友人に配る。2026-10-21）
- 1 回で：`powershell -NoProfile -ExecutionPolicy Bypass -File $p\tools\export_windows.ps1`（`--import` → `--export-release "Windows Desktop"` → README とライセンスを同梱 → `build\TryCard_v<config/version>.zip`）。出力は `build\windows\`（`TryCard.exe` + `TryCard.pck` + ログを見る用の `TryCard.console.exe`）。`build\.gdignore` はスクリプトが作る。版を上げるときは `project.godot` の `config/version` と `export_presets.cfg` の `file_version` / `product_version`。
- テンプレートは `%APPDATA%\Godot\export_templates\4.7.2.stable\` に Windows x86_64 の 4 つと `version.txt` だけを入れてある（公式の `.tpz` 約 1.2GB から `unzip -j` で取り出した。Godot を上げたらその版のものを入れ直す）。
- `export_presets.cfg` の `exclude_filter` で tests / tools / GUT / 自作プラグイン / 元のカード絵（`assets/AiGenerateCardArt`・`aiArt0N`、計約 170MB）を外している。**カード絵の元フォルダを新しく足したら exclude_filter にも足す**（外さないと pck が膨らむ）。ランタイムのコードは `res://tests` / `res://addons` を参照しない前提。
- アイコンは `python -I tools/app_icon.py`（カードの裏の紋章 → `icon.png` / `icon.ico`）。Godot 4.3 以降は exe へのアイコン埋め込みに rcedit は要らない（`application/modify_resources=true`）。
- 同梱物の原本は `tools/dist/README.txt`（日本語の遊び方・SmartScreen の説明・クレジット）。素材を足したら、クレジットとライセンスのコピー（スクリプトの `licenses` の部分）も足す。map paper の EULA は友人内の配布に限るという判断（公開するなら差し替え）。
- 確認：`build\windows\TryCard.console.exe --headless --quit-after 600`（エラーが出ないか）と、ウィンドウありで `--quit-after 900`。
- **落とし穴（実測）**：release テンプレートは `--main-pack` を拒否し（`compiled without overrides`）、`-s <script>` も実行されずに普通にゲームが起動して待ち続ける。debug テンプレートに同名の pck を置いても GUT は始まらなかった。書き出した物の中で GUT を回す方法は無いものとして、確認は上の起動と手で遊ぶことで行う。

## タイトル画面（StS2 に合わせた。2026-10-21）
- `MainMenuScreen`：背景は `assets/textures/backgrounds/title_campfire.jpg`（1920×1072）。上にロゴ（`python -I tools/title_logo.py` → `assets/textures/ui/title/logo.png`。仮のタイトル「Sxxx the SXXX」。文言は `LINES` で変える）。メニューは文字だけのボタン（テーマの `ButtonTitle`。ホバーで金色になり 1.08 倍）。デバッグ用の部品（シード・全カード）は右下の `DebugPanel` にまとめ、デバッグビルドでだけ出す。
- 背景の動き：空がうねる（`title_sky.gdshader`。UV の y が `sky_bottom` より上だけ）、霧と漂う光（戦闘背景のシェーダーを使い回す）、焚き火の炎・光・火の粉（休憩所と同じ部品。`RestScreen.make_embers()`）、塔の灯りの明滅（`campfire_glow` をゆっくりにしたもの）。位置は絵の px（`FLAME_RECT` など）。絵を差し替えたら測り直す。
- メニューの文言に漢字を足したら、`tools/banner_font.py` の `KANJI` に足してフォントを作り直す。元のフォントは google/fonts の `ofl/shipporiminchob1/ShipporiMinchoB1-ExtraBold.ttf` で、手元に無ければ scratchpad へダウンロードする。
- **落とし穴（実測）**：canvas_item シェーダーの `fragment()` で受け取る `COLOR` は、既にテクスチャの色が掛かった値。そこで自分で `texture(TEXTURE, uv)` を読んで `* COLOR` を掛けると、色が 2 回掛かって画面が約 1/3 の明るさになった。modulate を効かせたいときは、`vertex()` で `COLOR` を varying に写しておき、そちらを掛ける。
- 撮る：`capture_screens.gd` の `01_menu`（ロゴとメニューがフェードインし終わるのを 100 フレーム待つ）と `01b_menu_hover`。

## 図鑑（CompendiumScreen。2026-10-22）
- メインメニューの「図鑑」→ `Main.show_compendium()`（ランの外の画面。`main.tscn` の `compendium_scene`）→「戻る」/ Esc で `back_requested` → メニュー。セーブもランも作らない。
- 決定事項：タブ = カード / レリック / ポーション、最初から全部見える（発見の記録なし）。カードは `ContentLibrary.base_cards()`（強化版を除く。初期・状態異常・呪いを含む。「全カードで開始」と共用）。「強化版を表示」は強化できるカードだけ面を替える（件数は変わらない）。
- 絞り込みは同じ列の中が「または」、列どうしが「かつ」、空 = すべて。タブごとに覚える。状態異常と呪いは種類の絞り込みで 1 つ（`type_group`）。一覧の枠は最初に 1 回だけ作り、`_apply()` は表示 / 並び順だけ変える（作り直さない）。
- 操作（テストと撮影はこれを呼ぶ）：`select_tab` / `toggle_type_filter` / `toggle_rarity_filter` / `set_sort` / `set_show_upgraded` / `clear_filters` / `shown_items` / `open_detail(表示中の番号)` / `close_detail` / `detail_cards`。テストは `tests/unit/presentation/test_compendium.gd`。
- 一覧のカードは `mouse_filter = PASS`（STOP だとホイールが ScrollContainer に届かない）。レアリティの名前は `UiText.RELIC_RARITIES / POTION_RARITIES`。見出し・タブ・戻るはバナーのフォントなので、漢字を足したら `banner_font.py` の `KANJI` に足して作り直す。
- 撮る：`& $g --path $p -s $p\.claude\skills\trycard-dev\scripts\capture_compendium.gd -- <出力先>`（c01〜c08：メニュー / 一覧 / ホバー / 絞り込み + 強化版 / カードの拡大 / レリック / レリックの拡大 / ポーション）。`--headless` では `frame_post_draw` が来ずに止まるので、ウィンドウありで `Start-Process` ＋ タイムアウト。

## バランスの測定と調整（序盤の難易度。2026-10-21。GameDesign 付録 C の C62）
- 戦闘の強さ：`tests/sim/test_encounter_balance.gd` が初期デッキ・初期 HP で全エンカウントを `GreedyBot`（`tests/support/greedy_bot.gd`。カードのプレビューと敵のインテントから、エネルギーあたりの価値が最大の手を打つ。先読みなし・ポーションなし）に戦わせ、勝率・平均被ダメ・上位 10% の被ダメ・ターン数の表を `gut.p` で出す。表を見る：`& $g --headless --path $p -s addons/gut/gut_cmdln.gd -gdir=res://tests/sim -gselect=test_encounter_balance -gexit`（`TRYCARD_BALANCE_COMBATS`、既定 200）。目安（2026-10-21）：序盤用は平均被ダメ 0〜10、エリートの骨の巨像は 44。
- 序盤の行（`RunConfig.early_battle_rows` = 3 より前）の通常戦闘は `EncounterData.early = true` のものだけ（`MapGenerator.normal_encounters_for_row`。イベントから始まる戦闘も同じ）。エンカウントを足したら、上の表で被ダメを見て early を決め、`seed_content.gd` の `_add_encounter(..., early)` と `.tres` の両方に入れる。
- マップの出やすさ：`& $g --headless --path $p -s $p\.claude\skills\trycard-dev\scripts\map_stats.gd -- <戦闘> <イベント> <エリート> <休憩> <ショップ>`（重みを渡さなければ今の設定）で、2000 枚のマップの 1 ルートあたりの各種類の数・0〜4 行目の数・初めて出る行・最初の休憩までの戦闘数を出す。重みは「親と同じ種類にしない」規則で頭打ちになるので、数で決めずに測って決める。`node_weights` は `run_config.gd` の既定と `content/balance/run_config.tres` の両方を直す（配列は .tres に書かれている）。出始めの行は `elite_min_row` / `rest_shop_min_row`。

## 協力プレイ（LAN 2〜4 人。2026-10-23。GameDesign §21 / Architecture §23）
- 方式：ホストが順番を決めるコマンドのロックステップ。全員の PC が同じ RunController / Combat を持ち、`CoopCommands.apply(run, {seat, op, args})` を同じ順に実行する。カード・ユニットは uid で指す。
- **画面からランを操作するときは必ず `Party.act(run, CoopCommands.XXX, args, on_done)`（戦闘は `Party.act_combat`）**。1 人プレイはその場で同期実行、協力プレイはホスト経由で `on_done(ok)` が後から来る。結果の表示は on_done の中で行う（戻り値を当てにしない）。`run.xxx()` を画面から直接呼ぶと協力プレイでその PC だけ状態が変わり、同期ずれになる。
- **自分の値は `Party.me(run)` / `CombatScreen.me()` / `Party.seat()` から読む**。`run.state.hp` などは `RunState.active`（ルール側が処理中の人）、`combat.player` / `combat.piles` は `Combat.seat`（同）で、ほかの人のコマンドを処理すると変わる。クエリには席を渡す（`run.can_buy(i, Party.seat())`、`ctl.card_text(card, t, kw, seat)`）。
- ルール側（③④）で「たまたま今の席」を使わない：コマンド・ターンの手順・キューの処理（`ResolveEffectAction` は現場から、`TriggerCardAction` は積んだ席、`_finish_play` は出した席）がそれぞれ席を切り替える。敵 AI は `combat.lead_player()`。1 人プレイの動き（既存テスト）は変えない。
- 新しいラン中の操作を足すとき：RunController / CombatController に `who` / `seat` 引数 → `CoopCommands` に op と apply の分岐 → 画面は Party 経由。`CoopCommands.digest` に関係する状態が入っているか確認（入っていないとずれを検出できない）。
- テスト：`test_coop_combat` / `test_coop_run`（純粋なルール）、`test_net_session`（1 つのプロセスで 2 台分の Net：`get_tree().set_multiplayer(SceneMultiplayer.new(), 枝のパス)` で枝ごとに別の MultiplayerAPI。両方 `/<枝>/Net` なので RPC のパスがそろう。ポートは `net.port` で 24690 に変える）。
- **スモークテスト**（本物の Main を 2 プロセス、UiBot が 1 ランを最後まで）：`powershell -NoProfile -ExecutionPolicy Bypass -File $p\.claude\skills\trycard-dev\scripts\coop_smoke.ps1 -Seed 1`（約 30 秒。1 アクト 7 行・HP 600）。`COOP_SMOKE {...}` の desyncs = 0・failure 空・exit=0 を見る。ログは `%TEMP%\trycard_coop_smoke\{host,client}.out.txt`（`[net] sent N op` / `cmd N op -> ok`）。シードを数個回す（タイミングで結果が変わる）。
- 撮る：`& $g --path $p -s $p\.claude\skills\trycard-dev\scripts\capture_coop.gd -- <出力先>`（coop_01_lobby = 4 人のロビー、coop_02_combat = 4 人の戦闘。接続はせず Net の状態だけ作る）。
- **落とし穴（実測）**：ENet の接続を `close()` で即座に閉じると、直前に送ったコマンドと切断の通知が相手の同じ受信処理に入ったとき、相手の ENetMultiplayerPeer が読む前のパケットを捨てる（最後の ack_combat が届かず参加者だけ結果画面にならない）。`flush()` も `disconnect_peer()`（穏やかな切断）も効かなかった。`Net.leave()` は 1 秒（`CLOSE_GRACE`）接続を生かして `poll()` してから閉じる。
- 落とし穴：参加者がホストのコマンドを適用する前に同じ操作をもう一度送ると二重になる。画面は返事待ちの間（`CombatScreen._sending`）や「進む」を押した後（`PlayerState.done`）は押しても取り消しにしか使わない。UiBot も同じ待ち方をする。
- 協力プレイのセーブはホストだけ（`SaveManager.use_coop_path(true)` → `user://saves/coop_run.json`）。「続きから」はロビーでホストが選び、セーブと同じ人数・同じ名前の人を同じ席に並べ替えて開始する。
- ロビーのバナーのフォント：タイトルの「協力プレイ」と矢印の「待機中」の漢字は `banner_font.py` の KANJI に入れてある（文言を変えたら作り直す）。


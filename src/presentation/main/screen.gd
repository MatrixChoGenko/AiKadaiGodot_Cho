class_name Screen extends Control
## ⑤ Presentation：画面の基底クラス。ScreenHost が同時に 1 つだけ表示する（Architecture §13.1）。
## Main は enter(args) に run（RunController）と modals（ModalHost）と top_bar（TopBar）を渡す。画面はラン中の操作を run のコマンドで行い、
## フェーズの遷移は run.phase_changed を受けた Main が行う（ルール 8）。

## ランの表示（HP・ゴールドなど）が変わった。Main がトップバーを更新する。
signal run_changed
## メインメニューへ戻りたい（勝利 / 敗北画面）。
signal main_menu_requested

## この画面でトップバーを表示するか。
@export var show_top_bar: bool = true

var run: RunController
var modals: ModalHost
## 常駐のトップバー（Main の外で画面を出すとき = 戦闘のサンドボックス・テストでは null）。
var top_bar: TopBar


## 表示直後に ScreenHost から呼ばれる。args は画面ごとの引数。
## 派生クラスは super.enter(args) を呼んでから自分の引数を読む。
func enter(args: Dictionary) -> void:
	run = args.get(&"run") as RunController
	modals = args.get(&"modals") as ModalHost
	top_bar = args.get(&"top_bar") as TopBar


## 破棄の直前に ScreenHost から呼ばれる。
func exit() -> void:
	pass


## 次の画面の背景として残されたとき（exit() の後）に ScreenHost から呼ばれる。入力を止め、操作用の表示を隠す。
func enter_backdrop() -> void:
	pass


## カード一覧モーダルを開く（modals が無ければ null）。
func open_card_list(args: Dictionary) -> CardListModal:
	if modals == null:
		return null
	return modals.push(preload("res://scenes/widgets/card_list_modal.tscn"), args) as CardListModal

class_name Modal extends Control
## ⑤ Presentation：ModalHost に積まれるダイアログの基底クラス（カード選択、デッキ閲覧、確認ダイアログ）。

signal closed
## キャンセル（Esc / 閉じるボタン）で閉じたとき。closed より先に出る。
signal cancelled

## Esc（ui_cancel）で閉じられるか。戦闘中のカード選択など、キャンセル不可のものは false。
@export var cancellable: bool = true


## 表示直後に ModalHost から呼ばれる。
func enter(_args: Dictionary) -> void:
	pass


func close() -> void:
	closed.emit()


func cancel() -> void:
	if not cancellable:
		return
	cancelled.emit()
	close()

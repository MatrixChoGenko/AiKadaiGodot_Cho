extends Node
## ① Platform / Autoload `Settings`：ラン外の設定（手触り・音量・言語・ウィンドウ）。
## `user://settings.cfg`（ConfigFile）に保存する。M0 では値の保持と signal だけで、読み書きは M6/M7 で実装する。

@warning_ignore("unused_signal")  # M6 で設定変更時に emit する
signal changed(key: StringName)

const PATH: String = "user://settings.cfg"

## 全体のアニメーション速度の倍率（1× / 2× / 4×）。CombatPresenter が参照する。
var anim_speed: float = 1.0
var slow_mo_enabled: bool = true

class_name EventOutcome extends RefCounted
## ③ Domain：イベントの選択肢を選んだ結果（画面が結果テキストと「続ける」を出すための情報）。

var result_text: String = ""
## この選択で積まれたカード選択のリクエストの数（RunController.pending_request() で 1 つずつ処理する）。
var request_count: int = 0
## 戦闘が予約されたか（「続ける」で戦闘に入る）。
var battle_queued: bool = false

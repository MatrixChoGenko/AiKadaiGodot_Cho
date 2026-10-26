class_name StatusSet extends RefCounted
## ③ Domain：1 体のユニットのステータスの集合。並び順は付与された順（Hook の発動順と表示順）。
## スタックの増減は Combat の API 経由で行う（イベントを出すため）。ここは入れ物だけ。

var _stacks: Array[StatusStack] = []


func all() -> Array[StatusStack]:
	return _stacks


func find(status: StatusData) -> StatusStack:
	for s in _stacks:
		if s.data == status:
			return s
	return null


func find_id(status_id: StringName) -> StatusStack:
	for s in _stacks:
		if s.data.id == status_id:
			return s
	return null


func stacks_of(status: StatusData) -> int:
	var s := find(status)
	return s.stacks if s != null else 0


func add(stack: StatusStack) -> void:
	_stacks.append(stack)


func remove(stack: StatusStack) -> void:
	_stacks.erase(stack)


func is_empty() -> bool:
	return _stacks.is_empty()

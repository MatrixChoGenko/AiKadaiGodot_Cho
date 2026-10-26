@tool
extends EditorPlugin
## TryCard のエディタプラグイン（Architecture §17.2 / §17.3）。
## ツールメニュー：「コンテンツインデックス再構築」「コンテンツ検証」。content/ の .tres を保存すると自動で再構築する。

const MENU_REBUILD: String = "TryCard: コンテンツインデックス再構築"
const MENU_VALIDATE: String = "TryCard: コンテンツ検証"

var _rebuild_queued: bool = false


func _enter_tree() -> void:
	add_tool_menu_item(MENU_REBUILD, _rebuild_and_validate)
	add_tool_menu_item(MENU_VALIDATE, _validate)
	resource_saved.connect(_on_resource_saved)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_REBUILD)
	remove_tool_menu_item(MENU_VALIDATE)
	if resource_saved.is_connected(_on_resource_saved):
		resource_saved.disconnect(_on_resource_saved)


func _rebuild_and_validate() -> void:
	_rebuild_queued = false
	var lib := ContentIndexBuilder.rebuild()
	EditorInterface.get_resource_filesystem().update_file(ContentIndexBuilder.LIBRARY_PATH)
	print("TryCard: content index rebuilt (%d cards)" % lib.cards.size())
	_print_report(ContentValidator.new().validate(lib))


func _validate() -> void:
	_print_report(ContentValidator.new().validate(ContentIndexBuilder.collect()))


func _print_report(report: ValidationReport) -> void:
	if report.ok():
		print(report)
	else:
		push_warning(str(report))


func _on_resource_saved(resource: Resource) -> void:
	var path := resource.resource_path
	if not path.begins_with(ContentIndexBuilder.CONTENT_DIR) or path == ContentIndexBuilder.LIBRARY_PATH:
		return
	# 連続して保存されたときは 1 回にまとめる。
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild_and_validate.call_deferred()

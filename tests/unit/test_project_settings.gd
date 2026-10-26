extends GutTest
## M0 受け入れ：DevelopmentPlan §1 で決めたプロジェクト設定が入っていること。

const AUTOLOADS: Array[String] = ["Content", "SaveManager", "Settings", "Audio", "TimeFx", "Fx", "Log"]


func test_renderer_is_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")


func test_base_resolution_and_stretch() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")


func test_autoloads_registered_and_alive() -> void:
	for name in AUTOLOADS:
		assert_true(ProjectSettings.has_setting("autoload/" + name), "autoload %s not registered" % name)
		assert_not_null(get_tree().root.get_node_or_null(name), "autoload %s not in tree" % name)


func test_engine_version_pinned() -> void:
	var v := Engine.get_version_info()
	assert_eq("%d.%d.%d" % [v["major"], v["minor"], v["patch"]], "4.7.2")

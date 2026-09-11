extends Node
func _ready() -> void:
	await get_tree().process_frame
	print("viewport visible_rect: %s" % get_viewport().get_visible_rect().size)
	print("window size: %s" % DisplayServer.window_get_size())
	print("proje ayari: %s x %s" % [
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")])
	get_tree().quit(0)

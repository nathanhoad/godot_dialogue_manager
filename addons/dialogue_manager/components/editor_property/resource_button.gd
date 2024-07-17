@tool
extends Button


signal resource_dropped(next_resource: Resource)


var resource: Resource:
	set(next_resource):
		resource = next_resource
		if resource:
			icon = Engine.get_meta("DialogueManagerPlugin")._get_plugin_icon()
			text = resource.resource_path.get_file().replace(".dialogue", "")
		else:
			icon = null
			text = "<empty>"
	get:
		return resource


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			var data = get_viewport().gui_get_drag_data()
			if typeof(data) == TYPE_DICTIONARY and data.type == "files" and data.files.size() > 0 and data.files[0].ends_with(".dialogue"):
				add_theme_stylebox_override("normal", get_theme_stylebox("focus", "LineEdit"))
				add_theme_stylebox_override("hover", get_theme_stylebox("focus", "LineEdit"))

		NOTIFICATION_DRAG_END:
			self.resource = resource
			remove_theme_stylebox_override("normal")
			remove_theme_stylebox_override("hover")


func _can_drop_data(at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY: return false
	if data.type != "files": return false

	var files: PackedStringArray = Array(data.files).filter(func(f): return f.get_extension() == "dialogue")
	return files.size() > 0


func _drop_data(at_position: Vector2, data) -> void:
	var files: PackedStringArray = Array(data.files).filter(func(f): return f.get_extension() == "dialogue")

	if files.size() == 0: return

	resource_dropped.emit(load(files[0]))

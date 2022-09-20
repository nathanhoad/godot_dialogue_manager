tool
extends EditorPlugin


const DialogueResource = preload("res://addons/dialogue_manager/dialogue_resource.gd")
const DialogueExportPlugin = preload("res://addons/dialogue_manager/editor_export_plugin.gd")

const MainView = preload("res://addons/dialogue_manager/views/main_view.tscn")


var export_plugin = DialogueExportPlugin.new()
var main_view


func _enter_tree() -> void:
	add_autoload_singleton("DialogueManager", "res://addons/dialogue_manager/dialogue_manager.gd")
	add_custom_type("DialogueLabel", "RichTextLabel", preload("res://addons/dialogue_manager/dialogue_label.gd"), get_plugin_icon())
	
	add_tool_menu_item("Prepare for Dialogue Manager 2", self, "_prepare_for_dialogue_manager_2")
	
	if Engine.editor_hint:
		add_export_plugin(export_plugin)
		
		main_view = MainView.instance()
		get_editor_interface().get_editor_viewport().add_child(main_view)
		main_view.plugin = self
		make_visible(false)


func _exit_tree() -> void:
	remove_custom_type("DialogueLabel")
	remove_autoload_singleton("DialogueManager")
	
	remove_tool_menu_item("Prepare for Dialogue Manager 2")
	
	if is_instance_valid(main_view):
		main_view.queue_free()
	
	if export_plugin:
		remove_export_plugin(export_plugin)


func has_main_screen() -> bool:
	return true


func make_visible(next_visible: bool) -> void:
	if is_instance_valid(main_view):
		main_view.visible = next_visible


func get_plugin_name() -> String:
	return "Dialogue"


func get_plugin_icon() -> Texture:
	var base_color = get_editor_interface().get_editor_settings().get_setting("interface/theme/base_color")
	var theme = "light" if base_color.v > 0.5 else "dark"
	var base_icon = load("res://addons/dialogue_manager/assets/icons/icon_%s.svg" % [theme]) as Texture
	
	var size = get_editor_interface().get_editor_viewport().get_icon("Godot", "EditorIcons").get_size()
	var image: Image = base_icon.get_data()
	image.resize(size.x, size.y, Image.INTERPOLATE_TRILINEAR)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture


func handles(object) -> bool:
	return object is DialogueResource


func edit(object) -> void:
	if is_instance_valid(main_view):
		main_view.open_resource(object)
	

func apply_changes() -> void:
	if is_instance_valid(main_view):
		main_view.apply_changes()


func _prepare_for_dialogue_manager_2(ud) -> void:
	# Find all dialogue resources and create new ones
	var items = _create_dialogue_resource_files("res://")
	for item in items:
		var raw_text: String = item.text
		var lines: PoolStringArray = raw_text.split("\n")
		var is_first_title: bool = true
		for i in range(0, lines.size()):
			var line: String = lines[i]
			if line.begins_with("~ "):
				if is_first_title:
					is_first_title = false
				else:
					# Add an end before the next title
					lines[i] = "=> END\n" + lines[i]
					
			# Replace translations with IDs
			line = line.replace("[TR:", "[ID:")
		
		raw_text = lines.join("\n")
		
		var new_path = item.path.replace(".tres", ".dialogue")
		
		var file = File.new()
		file.open(new_path, File.WRITE)
		file.store_string(raw_text)
		file.close()
		
		prints("Created", new_path)
	
	# Show a message
	var accept_dialog: AcceptDialog = AcceptDialog.new()
	accept_dialog.window_title = "Done"
	accept_dialog.dialog_text = "Finished preparing %d files." % items.size()
	get_editor_interface().get_base_control().add_child(accept_dialog)
	accept_dialog.popup_centered()


func _create_dialogue_resource_files(path: String) -> Array:
	var files: Array = []
	
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.plus_file(file_name)
			if file_name in [".", "..", ".import", ".github"]:
				pass
			elif dir.current_is_dir():
				files.append_array(_create_dialogue_resource_files(full_path))
			elif file_name.get_extension() == "tres":
				# We need to open the file to check it
				var resource = load(full_path)
				if resource is DialogueResource:
					files.append({ path = full_path, text = resource.raw_text })
			file_name = dir.get_next()
	
	return files

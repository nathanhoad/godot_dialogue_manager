@tool
extends VBoxContainer


signal file_selected(file_path: String)
signal file_popup_menu_requested(at_position: Vector2)
signal file_double_clicked(file_path: String)


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")

const MODIFIED_SUFFIX = "(*)"


@onready var filter_edit: LineEdit = $FilterEdit
@onready var list: ItemList = $List

var file_map: Dictionary = {}

var current_file_path: String = ""

var files: PackedStringArray = []:
	set(next_files):
		files = next_files
		files.sort()
		update_file_map()
		apply_filter()
	get:
		return files

var unsaved_files: Array[String] = []

var filter: String:
	set(next_filter):
		filter = next_filter
		apply_filter()
	get:
		return filter


func _ready() -> void:
	apply_theme()
	
	filter_edit.placeholder_text = DialogueConstants.translate("files_list.filter")


func select_file(file: String) -> void:
	list.deselect_all()
	for i in range(0, list.get_item_count()):
		var item_text = list.get_item_text(i).replace(MODIFIED_SUFFIX, "")
		if item_text == get_nice_file(file, item_text.count("/") + 1):
			list.select(i)


func mark_file_as_unsaved(file: String, is_unsaved: bool) -> void:
	if not file in unsaved_files and is_unsaved:
		unsaved_files.append(file)
	elif file in unsaved_files and not is_unsaved:
		unsaved_files.erase(file)
	apply_filter()


func update_file_map() -> void:
	file_map = {}
	for file in files:
		var nice_file: String = get_nice_file(file)
		
		# See if a value with just the file name is already in the map
		for key in file_map.keys():
			if file_map[key] == nice_file:
				var bit_count = nice_file.count("/") + 2
				
				var existing_nice_file = get_nice_file(key, bit_count)
				nice_file = get_nice_file(file, bit_count)
				
				while nice_file == existing_nice_file:
					bit_count += 1
					existing_nice_file = get_nice_file(key, bit_count)
					nice_file = get_nice_file(file, bit_count)
				
				file_map[key] = existing_nice_file
		
		file_map[file] = nice_file


func get_nice_file(file_path: String, path_bit_count: int = 1) -> String:
	var bits = file_path.replace("res://", "").replace(".dialogue", "").split("/")
	bits = bits.slice(-path_bit_count)
	return "/".join(bits)


func apply_filter() -> void:
	list.clear()
	for file in file_map.keys():
		if filter == "" or filter.to_lower() in file.to_lower():
			var nice_file = file_map[file]
			if file in unsaved_files:
				nice_file += MODIFIED_SUFFIX
			list.add_item(nice_file)
	
	select_file(current_file_path)


func apply_theme() -> void:
	if is_instance_valid(filter_edit):
		filter_edit.right_icon = get_theme_icon("Search", "EditorIcons")


### Signals


func _on_theme_changed() -> void:
	apply_theme()


func _on_filter_edit_text_changed(new_text: String) -> void:
	self.filter = new_text


func _on_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		var item_text = list.get_item_text(index).replace(MODIFIED_SUFFIX, "")
		var file = file_map.find_key(item_text)
		select_file(file)
		file_selected.emit(file)
	
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		file_popup_menu_requested.emit(at_position)


func _on_list_item_activated(index: int) -> void:
	var item_text = list.get_item_text(index).replace(MODIFIED_SUFFIX, "")
	var file = file_map.find_key(item_text)
	select_file(file)
	file_double_clicked.emit(file)

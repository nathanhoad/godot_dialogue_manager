tool
extends WindowDialog


signal script_button_pressed(path)


const Settings = preload("res://addons/dialogue_manager/components/settings.gd")


export var _settings := NodePath()

onready var settings: Settings = get_node(_settings)
onready var errors_button := $Margin/VBox/Tabs/Editor/VBox/CheckForErrorsButton
onready var missing_translations_button := $Margin/VBox/Tabs/Editor/VBox/MissingTranslationsButton
onready var globals_list := $Margin/VBox/Tabs/Runtime/VBox/GlobalsList
onready 	var skip_typing_option_button := $Margin/VBox/Tabs/Input/GridContainer/SkipTypingOptionButton

var dialogue_manager_config := ConfigFile.new()
var all_globals: Dictionary = {}
var enabled_globals: Array = []


func _initialize_editor_tab():
	errors_button.pressed = settings.get_editor_value("check_for_errors", true)
	missing_translations_button.pressed = settings.get_editor_value("missing_translations_are_errors", false)


func _initialize_globals_tab():
	var project = ConfigFile.new()
	var err = project.load("res://project.godot")
	assert(err == OK, "Could not find the project file")
	
	all_globals.clear()
	if project.has_section("autoload"):
		for key in project.get_section_keys("autoload"):
			if key != "DialogueManager":
				all_globals[key] = project.get_value("autoload", key)
	
	enabled_globals = settings.get_runtime_value("states", [])
	globals_list.clear()
	var root = globals_list.create_item()
	for name in all_globals.keys():
		var item = globals_list.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, name in enabled_globals)
		item.set_text(0, name)
		item.add_button(1, get_icon("Edit", "EditorIcons"))
		item.set_text(2, all_globals.get(name).replace("*res://", "res://"))
	
	globals_list.set_column_expand(0, false)
	globals_list.set_column_min_width(0, 250)
	globals_list.set_column_expand(1, false)
	globals_list.set_column_min_width(1, 40)
	globals_list.set_column_titles_visible(true)
	globals_list.set_column_title(0, "Autoload")
	globals_list.set_column_title(1, "")
	globals_list.set_column_title(2, "Path")


func _initialize_input_tab():
	var actions: Array = InputMap.get_actions()
	for index in actions.size():
		var action: String = actions[index]
		skip_typing_option_button.add_item(action)
		skip_typing_option_button.set_item_metadata(index, action)
		if action == settings.get_input_value("skip_typing", "ui_cancel"):
			skip_typing_option_button.selected = index


### Signals


func _on_SettingsDialog_about_to_show():
	_initialize_editor_tab()
	_initialize_globals_tab()
	_initialize_input_tab()


func _on_GlobalsList_item_selected():
	var item = globals_list.get_selected()
	var is_checked = !item.is_checked(0)
	item.set_checked(0, is_checked)
	
	if is_checked:
		enabled_globals.append(item.get_text(0))
	else:
		enabled_globals.erase(item.get_text(0))
	
	settings.set_runtime_value("states", enabled_globals)


func _on_CheckForErrorsButton_toggled(button_pressed: bool) -> void:
	settings.set_editor_value("check_for_errors", button_pressed)


func _on_MissingTranslationsButton_toggled(button_pressed):
	settings.set_editor_value("missing_translations_are_errors", button_pressed)


func _on_DoneButton_pressed():
	hide()


func _on_GlobalsList_button_pressed(item, column, id):
	hide()
	emit_signal("script_button_pressed", item.get_text(2))


func _on_SkipTypingOptionButton_item_selected(index: int) -> void:
	var action: String = skip_typing_option_button.get_item_metadata(index)
	settings.set_input_value("skip_typing", action)

@tool
extends VBoxContainer


signal script_button_pressed(path: String)


const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")


@onready var missing_translations_button: CheckBox = $MissingTranslationsButton
@onready var wrap_lines_button: Button = $WrapLinesButton
@onready var include_all_responses_button: Button = $IncludeAllResponsesButton
@onready var states_title: Label = $StatesTitle
@onready var globals_list: Tree = $GlobalsList

var all_globals: Dictionary = {}
var enabled_globals: Array = []


func prepare() -> void:
	states_title.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))
	
	missing_translations_button.set_pressed_no_signal(DialogueSettings.get_setting("missing_translations_are_errors", false))
	wrap_lines_button.set_pressed_no_signal(DialogueSettings.get_setting("wrap_lines", false))
	include_all_responses_button.set_pressed_no_signal(DialogueSettings.get_setting("include_all_responses", false))

	var project = ConfigFile.new()
	var err = project.load("res://project.godot")
	assert(err == OK, "Could not find the project file")
	
	all_globals.clear()
	if project.has_section("autoload"):
		for key in project.get_section_keys("autoload"):
			if key != "DialogueManager":
				all_globals[key] = project.get_value("autoload", key)
	
	enabled_globals = DialogueSettings.get_setting("states", [])
	globals_list.clear()
	var root = globals_list.create_item()
	for name in all_globals.keys():
		var item: TreeItem = globals_list.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, name in enabled_globals)
		item.set_text(0, name)
		item.add_button(1, get_theme_icon("Edit", "EditorIcons"))
		item.set_text(2, all_globals.get(name, "").replace("*res://", "res://"))
	
	globals_list.set_column_expand(0, false)
	globals_list.set_column_custom_minimum_width(0, 250)
	globals_list.set_column_expand(1, false)
	globals_list.set_column_custom_minimum_width(1, 40)
	globals_list.set_column_titles_visible(true)
	globals_list.set_column_title(0, "Autoload")
	globals_list.set_column_title(1, "")
	globals_list.set_column_title(2, "Path")


### Signals


func _on_settings_view_visibility_changed() -> void:
	prepare()


func _on_missing_translations_button_toggled(button_pressed: bool) -> void:
	DialogueSettings.set_setting("missing_translations_are_errors", button_pressed)


func _on_wrap_lines_button_toggled(button_pressed: bool) -> void:
	DialogueSettings.set_setting("wrap_lines", button_pressed)


func _on_include_all_responses_button_toggled(button_pressed: bool) -> void:
	DialogueSettings.set_setting("include_all_responses", button_pressed)


func _on_globals_list_item_selected() -> void:
	var item = globals_list.get_selected()
	var is_checked = not item.is_checked(0)	
	item.set_checked(0, is_checked)
	
	if is_checked:
		enabled_globals.append(item.get_text(0))
	else:
		enabled_globals.erase(item.get_text(0))
	
	DialogueSettings.set_setting("states", enabled_globals)


func _on_globals_list_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	emit_signal("script_button_pressed", item.get_text(2))

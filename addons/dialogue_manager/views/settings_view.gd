@tool
extends TabContainer


signal script_button_pressed(path: String)


const DialogueConstants = preload("../constants.gd")
const DialogueSettings = preload("../components/settings.gd")


enum PathTarget {
	CustomTestScene,
	Balloon
}


# Editor
@onready var new_template_button: CheckBox = $Editor/NewTemplateButton
@onready var missing_translations_button: CheckBox = $Editor/MissingTranslationsButton
@onready var characters_translations_button: CheckBox = $Editor/CharactersTranslationsButton
@onready var wrap_lines_button: Button = $Editor/WrapLinesButton
@onready var test_scene_path_input: LineEdit = $Editor/CustomTestScene/TestScenePath
@onready var revert_test_scene_button: Button = $Editor/CustomTestScene/RevertTestScene
@onready var load_test_scene_button: Button = $Editor/CustomTestScene/LoadTestScene
@onready var custom_test_scene_file_dialog: FileDialog = $CustomTestSceneFileDialog
@onready var default_csv_locale: LineEdit = $Editor/DefaultCSVLocale

# Runtime
@onready var include_all_responses_button: CheckBox = $Runtime/IncludeAllResponsesButton
@onready var ignore_missing_state_values: CheckBox = $Runtime/IgnoreMissingStateValues
@onready var balloon_path_input: LineEdit = $Runtime/CustomBalloon/BalloonPath
@onready var revert_balloon_button: Button = $Runtime/CustomBalloon/RevertBalloonPath
@onready var load_balloon_button: Button = $Runtime/CustomBalloon/LoadBalloonPath
@onready var states_title: Label = $Runtime/StatesTitle
@onready var globals_list: Tree = $Runtime/GlobalsList

var editor_plugin: EditorPlugin
var all_globals: Dictionary = {}
var enabled_globals: Array = []
var path_target: PathTarget = PathTarget.CustomTestScene

var _default_test_scene_path: String = preload("../test_scene.tscn").resource_path


func _ready() -> void:
	new_template_button.text = DialogueConstants.translate("settings.new_template")
	missing_translations_button.text = DialogueConstants.translate("settings.missing_keys")
	$Editor/MissingTranslationsHint.text = DialogueConstants.translate("settings.missing_keys_hint")
	characters_translations_button.text = DialogueConstants.translate("settings.characters_translations")
	wrap_lines_button.text = DialogueConstants.translate("settings.wrap_long_lines")
	$Editor/CustomTestSceneLabel.text = DialogueConstants.translate("settings.custom_test_scene")
	$Editor/DefaultCSVLocaleLabel.text = DialogueConstants.translate("settings.default_csv_locale")

	include_all_responses_button.text = DialogueConstants.translate("settings.include_failed_responses")
	ignore_missing_state_values.text = DialogueConstants.translate("settings.ignore_missing_state_values")
	$Runtime/CustomBalloonLabel.text = DialogueConstants.translate("settings.default_balloon_hint")
	states_title.text = DialogueConstants.translate("settings.states_shortcuts")
	$Runtime/StatesMessage.text = DialogueConstants.translate("settings.states_message")
	$Runtime/StatesHint.text = DialogueConstants.translate("settings.states_hint")


func prepare() -> void:
	test_scene_path_input.placeholder_text = DialogueSettings.get_setting("custom_test_scene_path", _default_test_scene_path)
	revert_test_scene_button.visible = test_scene_path_input.placeholder_text != _default_test_scene_path
	revert_test_scene_button.icon = get_theme_icon("RotateLeft", "EditorIcons")
	revert_test_scene_button.tooltip_text = DialogueConstants.translate("settings.revert_to_default_test_scene")
	load_test_scene_button.icon = get_theme_icon("Load", "EditorIcons")

	var balloon_path: String = DialogueSettings.get_setting("balloon_path", "")
	balloon_path_input.placeholder_text = balloon_path if balloon_path != "" else DialogueConstants.translate("settings.default_balloon_path")
	revert_balloon_button.visible = balloon_path != ""
	revert_balloon_button.icon = get_theme_icon("RotateLeft", "EditorIcons")
	revert_balloon_button.tooltip_text = DialogueConstants.translate("settings.revert_to_default_balloon")
	load_balloon_button.icon = get_theme_icon("Load", "EditorIcons")

	var scale: float = editor_plugin.get_editor_interface().get_editor_scale()
	custom_test_scene_file_dialog.min_size = Vector2(600, 500) * scale

	states_title.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))

	missing_translations_button.set_pressed_no_signal(DialogueSettings.get_setting("missing_translations_are_errors", false))
	characters_translations_button.set_pressed_no_signal(DialogueSettings.get_setting("export_characters_in_translation", true))
	wrap_lines_button.set_pressed_no_signal(DialogueSettings.get_setting("wrap_lines", false))
	include_all_responses_button.set_pressed_no_signal(DialogueSettings.get_setting("include_all_responses", false))
	ignore_missing_state_values.set_pressed_no_signal(DialogueSettings.get_setting("ignore_missing_state_values", false))
	new_template_button.set_pressed_no_signal(DialogueSettings.get_setting("new_with_template", true))
	default_csv_locale.text = DialogueSettings.get_setting("default_csv_locale", "en")

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
	globals_list.set_column_title(0, DialogueConstants.translate("settings.autoload"))
	globals_list.set_column_title(1, "")
	globals_list.set_column_title(2, DialogueConstants.translate("settings.path"))


### Signals


func _on_settings_view_visibility_changed() -> void:
	prepare()


func _on_missing_translations_button_toggled(button_pressed: bool) -> void:
	DialogueSettings.set_setting("missing_translations_are_errors", button_pressed)


func _on_characters_translations_button_toggled(button_pressed: bool) -> void:
	DialogueSettings.set_setting("export_characters_in_translation", button_pressed)


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


func _on_sample_template_toggled(button_pressed):
	DialogueSettings.set_setting("new_with_template", button_pressed)


func _on_revert_test_scene_pressed() -> void:
	DialogueSettings.set_setting("custom_test_scene_path", _default_test_scene_path)
	test_scene_path_input.placeholder_text = _default_test_scene_path
	revert_test_scene_button.visible = test_scene_path_input.placeholder_text != _default_test_scene_path


func _on_load_test_scene_pressed() -> void:
	path_target = PathTarget.CustomTestScene
	custom_test_scene_file_dialog.popup_centered()


func _on_custom_test_scene_file_dialog_file_selected(path: String) -> void:
	match path_target:
		PathTarget.CustomTestScene:
			DialogueSettings.set_setting("custom_test_scene_path", path)
			test_scene_path_input.placeholder_text = path
			revert_test_scene_button.visible = test_scene_path_input.placeholder_text != _default_test_scene_path

		PathTarget.Balloon:
			DialogueSettings.set_setting("balloon_path", path)
			balloon_path_input.placeholder_text = path
			revert_balloon_button.visible = balloon_path_input.placeholder_text != ""


func _on_ignore_missing_state_values_toggled(button_pressed: bool) -> void:
	DialogueSettings.set_setting("ignore_missing_state_values", button_pressed)


func _on_default_csv_locale_text_changed(new_text: String) -> void:
	DialogueSettings.set_setting("default_csv_locale", new_text)


func _on_revert_balloon_path_pressed() -> void:
	DialogueSettings.set_setting("balloon_path", "")
	balloon_path_input.placeholder_text = DialogueConstants.translate("settings.default_balloon_path")
	revert_balloon_button.visible = DialogueSettings.get_setting("balloon_path", "") != ""


func _on_load_balloon_path_pressed() -> void:
	path_target = PathTarget.Balloon
	custom_test_scene_file_dialog.popup_centered()

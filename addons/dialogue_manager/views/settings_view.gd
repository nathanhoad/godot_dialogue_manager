@tool
extends TabContainer


signal script_button_pressed(path: String)


const DialogueConstants = preload("../constants.gd")
const DialogueSettings = preload("../settings.gd")
const BaseDialogueTestScene = preload("../test_scene.gd")


enum PathTarget {
	CustomTestScene,
	Balloon
}


# Editor
@onready var new_template_button: CheckBox = $Editor/NewTemplateButton
@onready var new_template: CodeEdit = $Editor/NewTemplate
@onready var characters_translations_button: CheckBox = $Editor/CharactersTranslationsButton
@onready var wrap_lines_button: Button = $Editor/WrapLinesButton
@onready var default_csv_locale: LineEdit = $Editor/DefaultCSVLocale

# Runtime
@onready var include_all_responses_button: CheckBox = $Runtime/IncludeAllResponsesButton
@onready var ignore_missing_state_values: CheckBox = $Runtime/IgnoreMissingStateValues
@onready var balloon_path_input: LineEdit = $Runtime/CustomBalloon/BalloonPath
@onready var revert_balloon_button: Button = $Runtime/CustomBalloon/RevertBalloonPath
@onready var load_balloon_button: Button = $Runtime/CustomBalloon/LoadBalloonPath
@onready var states_title: Label = $Runtime/StatesTitle
@onready var globals_list: Tree = $Runtime/GlobalsList

# Advanced
@onready var check_for_updates: CheckBox = $Advanced/CheckForUpdates
@onready var include_characters_in_translations: CheckBox = $Advanced/IncludeCharactersInTranslations
@onready var include_notes_in_translations: CheckBox = $Advanced/IncludeNotesInTranslations
@onready var open_in_external_editor_button: CheckBox = $Advanced/OpenInExternalEditorButton
@onready var test_scene_path_input: LineEdit = $Advanced/CustomTestScene/TestScenePath
@onready var revert_test_scene_button: Button = $Advanced/CustomTestScene/RevertTestScene
@onready var load_test_scene_button: Button = $Advanced/CustomTestScene/LoadTestScene
@onready var custom_test_scene_file_dialog: FileDialog = $CustomTestSceneFileDialog
@onready var create_lines_for_response_characters: CheckBox = $Advanced/CreateLinesForResponseCharacters
@onready var missing_translations_button: CheckBox = $Advanced/MissingTranslationsButton

var all_globals: Dictionary = {}
var enabled_globals: Array = []
var path_target: PathTarget = PathTarget.CustomTestScene

var _default_test_scene_path: String = preload("../test_scene.tscn").resource_path

var _recompile_if_changed_settings: Dictionary


func _ready() -> void:
	new_template_button.text = DialogueConstants.translate(&"settings.new_template")
	characters_translations_button.text = DialogueConstants.translate(&"settings.characters_translations")
	wrap_lines_button.text = DialogueConstants.translate(&"settings.wrap_long_lines")
	$Editor/DefaultCSVLocaleLabel.text = DialogueConstants.translate(&"settings.default_csv_locale")

	include_all_responses_button.text = DialogueConstants.translate(&"settings.include_failed_responses")
	ignore_missing_state_values.text = DialogueConstants.translate(&"settings.ignore_missing_state_values")
	$Runtime/CustomBalloonLabel.text = DialogueConstants.translate(&"settings.default_balloon_hint")
	states_title.text = DialogueConstants.translate(&"settings.states_shortcuts")
	$Runtime/StatesMessage.text = DialogueConstants.translate(&"settings.states_message")
	$Runtime/StatesHint.text = DialogueConstants.translate(&"settings.states_hint")

	check_for_updates.text = DialogueConstants.translate(&"settings.check_for_updates")
	include_characters_in_translations.text = DialogueConstants.translate(&"settings.include_characters_in_translations")
	include_notes_in_translations.text = DialogueConstants.translate(&"settings.include_notes_in_translations")
	open_in_external_editor_button.text = DialogueConstants.translate(&"settings.open_in_external_editor")
	$Advanced/ExternalWarning.text = DialogueConstants.translate(&"settings.external_editor_warning")
	$Advanced/CustomTestSceneLabel.text = DialogueConstants.translate(&"settings.custom_test_scene")
	$Advanced/RecompileWarning.text = DialogueConstants.translate(&"settings.recompile_warning")
	missing_translations_button.text = DialogueConstants.translate(&"settings.missing_keys")
	$Advanced/MissingTranslationsHint.text = DialogueConstants.translate(&"settings.missing_keys_hint")
	create_lines_for_response_characters.text = DialogueConstants.translate(&"settings.create_lines_for_responses_with_characters")

	current_tab = 0


func prepare() -> void:
	_recompile_if_changed_settings = _get_settings_that_require_recompilation()

	test_scene_path_input.placeholder_text = DialogueSettings.get_setting("custom_test_scene_path", _default_test_scene_path)
	revert_test_scene_button.visible = test_scene_path_input.placeholder_text != _default_test_scene_path
	revert_test_scene_button.icon = get_theme_icon("RotateLeft", "EditorIcons")
	revert_test_scene_button.tooltip_text = DialogueConstants.translate(&"settings.revert_to_default_test_scene")
	load_test_scene_button.icon = get_theme_icon("Load", "EditorIcons")

	var balloon_path: String = DialogueSettings.get_setting("balloon_path", "")
	if not FileAccess.file_exists(balloon_path):
		DialogueSettings.set_setting("balloon_path", "")
		balloon_path = ""
	balloon_path_input.placeholder_text = balloon_path if balloon_path != "" else DialogueConstants.translate(&"settings.default_balloon_path")
	revert_balloon_button.visible = balloon_path != ""
	revert_balloon_button.icon = get_theme_icon("RotateLeft", "EditorIcons")
	revert_balloon_button.tooltip_text = DialogueConstants.translate(&"settings.revert_to_default_balloon")
	load_balloon_button.icon = get_theme_icon("Load", "EditorIcons")

	var scale: float = Engine.get_meta("DialogueManagerPlugin").get_editor_interface().get_editor_scale()
	custom_test_scene_file_dialog.min_size = Vector2(600, 500) * scale

	states_title.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))

	check_for_updates.set_pressed_no_signal(DialogueSettings.get_user_value("check_for_updates", true))
	characters_translations_button.set_pressed_no_signal(DialogueSettings.get_setting("export_characters_in_translation", true))
	wrap_lines_button.set_pressed_no_signal(DialogueSettings.get_setting("wrap_lines", false))
	include_all_responses_button.set_pressed_no_signal(DialogueSettings.get_setting("include_all_responses", false))
	ignore_missing_state_values.set_pressed_no_signal(DialogueSettings.get_setting("ignore_missing_state_values", false))
	new_template_button.set_pressed_no_signal(DialogueSettings.get_setting("new_with_template", true))
	new_template.text = DialogueSettings.get_setting("new_template", "")
	new_template.visible = DialogueSettings.get_setting("new_with_template", true)
	default_csv_locale.text = DialogueSettings.get_setting("default_csv_locale", "en")

	missing_translations_button.set_pressed_no_signal(DialogueSettings.get_setting("missing_translations_are_errors", false))
	create_lines_for_response_characters.set_pressed_no_signal(DialogueSettings.get_setting("create_lines_for_responses_with_characters", true))

	include_characters_in_translations.set_pressed_no_signal(DialogueSettings.get_setting("include_character_in_translation_exports", false))
	include_notes_in_translations.set_pressed_no_signal(DialogueSettings.get_setting("include_notes_in_translation_exports", false))
	open_in_external_editor_button.set_pressed_no_signal(DialogueSettings.get_user_value("open_in_external_editor", false))

	var editor_settings: EditorSettings = Engine.get_meta("DialogueManagerPlugin").get_editor_interface().get_editor_settings()
	var external_editor: String = editor_settings.get_setting("text_editor/external/exec_path")
	var use_external_editor: bool = editor_settings.get_setting("text_editor/external/use_external_editor") and external_editor != ""
	if not use_external_editor:
		open_in_external_editor_button.hide()
		$Advanced/ExternalWarning.hide()
		$Advanced/ExternalSeparator.hide()

	var project = ConfigFile.new()
	var err = project.load("res://project.godot")
	assert(err == OK, "Could not find the project file")

	all_globals.clear()
	if project.has_section("autoload"):
		for key in project.get_section_keys("autoload"):
			if key != "DialogueManager":
				all_globals[key] = project.get_value("autoload", key)

	enabled_globals = DialogueSettings.get_setting("states", []).duplicate()
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
	globals_list.set_column_title(0, DialogueConstants.translate(&"settings.autoload"))
	globals_list.set_column_title(1, "")
	globals_list.set_column_title(2, DialogueConstants.translate(&"settings.path"))


func apply_settings_changes() -> void:
	if _recompile_if_changed_settings != _get_settings_that_require_recompilation():
		Engine.get_meta("DialogueCache").reimport_files()


func _get_settings_that_require_recompilation() -> Dictionary:
	return DialogueSettings.get_settings([
		"missing_translations_are_errors",
		"create_lines_for_responses_with_characters"
	])


### Signals


func _on_missing_translations_button_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_setting("missing_translations_are_errors", toggled_on)


func _on_characters_translations_button_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_setting("export_characters_in_translation", toggled_on)


func _on_wrap_lines_button_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_setting("wrap_lines", toggled_on)


func _on_include_all_responses_button_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_setting("include_all_responses", toggled_on)


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


func _on_sample_template_toggled(toggled_on):
	DialogueSettings.set_setting("new_with_template", toggled_on)
	new_template.visible = toggled_on


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
			# Check that the test scene is a subclass of BaseDialogueTestScene
			var test_scene: PackedScene = load(path)
			if test_scene and test_scene.instantiate() is BaseDialogueTestScene:
				DialogueSettings.set_setting("custom_test_scene_path", path)
				test_scene_path_input.placeholder_text = path
				revert_test_scene_button.visible = test_scene_path_input.placeholder_text != _default_test_scene_path
			else:
				var accept: AcceptDialog = AcceptDialog.new()
				accept.dialog_text = DialogueConstants.translate(&"settings.invalid_test_scene").format({ path = path })
				add_child(accept)
				accept.popup_centered.call_deferred()

		PathTarget.Balloon:
			DialogueSettings.set_setting("balloon_path", path)
			balloon_path_input.placeholder_text = path
			revert_balloon_button.visible = balloon_path_input.placeholder_text != ""


func _on_ignore_missing_state_values_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_setting("ignore_missing_state_values", toggled_on)


func _on_default_csv_locale_text_changed(new_text: String) -> void:
	DialogueSettings.set_setting("default_csv_locale", new_text)


func _on_revert_balloon_path_pressed() -> void:
	DialogueSettings.set_setting("balloon_path", "")
	balloon_path_input.placeholder_text = DialogueConstants.translate(&"settings.default_balloon_path")
	revert_balloon_button.visible = DialogueSettings.get_setting("balloon_path", "") != ""


func _on_load_balloon_path_pressed() -> void:
	path_target = PathTarget.Balloon
	custom_test_scene_file_dialog.popup_centered()


func _on_create_lines_for_response_characters_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_setting("create_lines_for_responses_with_characters", toggled_on)


func _on_open_in_external_editor_button_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_user_value("open_in_external_editor", toggled_on)


func _on_include_characters_in_translations_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_setting("include_character_in_translation_exports", toggled_on)


func _on_include_notes_in_translations_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_setting("include_notes_in_translation_exports", toggled_on)


func _on_keep_up_to_date_toggled(toggled_on: bool) -> void:
	DialogueSettings.set_user_value("check_for_updates", toggled_on)


func _on_new_template_focus_exited() -> void:
	DialogueSettings.set_setting("new_template", new_template.text)

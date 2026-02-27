@tool
class_name DMSettings extends Node


#region Editor



## Wrap lines in the dialogue editor.
const WRAP_LONG_LINES: StringName = &"editor/wrap_long_lines"
## The template to start new dialogue files with.
const NEW_FILE_TEMPLATE: StringName = &"editor/new_file_template"

## Show lines without statis IDs as errors.
const MISSING_TRANSLATIONS_ARE_ERRORS: StringName = &"editor/translations/missing_translations_are_errors"
## Include character names in the list of translatable strings.
const INCLUDE_CHARACTERS_IN_TRANSLATABLE_STRINGS_LIST: StringName = &"editor/translations/include_characters_in_translatable_strings_list"
## Automatically update the project's list of translatable files when dialogue files are added or removed
const UPDATE_POT_FILES_AUTOMATICALLY: StringName = &"editor/translations/update_pot_files_automatically"

## A processor handling special case compilation.
const DIALOGUE_PROCESSOR_PATH: StringName = &"editor/advanced/dialogue_processor_path"

## A custom test scene to use when testing dialogue.
const CUSTOM_TEST_SCENE_PATH: StringName = &"editor/advanced/custom_test_scene_path"
## Extra script files to include in the auto-complete-able list
const EXTRA_AUTO_COMPLETE_SCRIPT_SOURCES: StringName = &"editor/advanced/extra_auto_complete_script_sources"

## The custom balloon for this game.
const BALLOON_PATH: StringName = &"runtime/balloon_path"
## The names of any autoloads to shortcut into all dialogue files (so you don't have to write `using SomeGlobal` in each file).
const STATE_AUTOLOAD_SHORTCUTS: StringName = &"runtime/state_autoload_shortcuts"
## Check for possible naming conflicts in state shortcuts.
const WARN_ABOUT_METHOD_PROPERTY_OR_SIGNAL_NAME_CONFLICTS: StringName = &"runtime/warn_about_method_property_or_signal_name_conflicts"

## Bypass any missing state when running dialogue.
const IGNORE_MISSING_STATE_VALUES: StringName = &"runtime/advanced/ignore_missing_state_values"
## Whether or not the project is utilising dotnet.
const USES_DOTNET: StringName = &"runtime/advanced/uses_dotnet"


static var SETTINGS_CONFIGURATION: Dictionary = {
	WRAP_LONG_LINES: {
		value = false,
		type = TYPE_BOOL,
	},
	NEW_FILE_TEMPLATE: {
		value = "~ start\nNathan: [[Hi|Hello|Howdy]], this is some dialogue.\nNathan: Here are some choices.\n- First one\n\tNathan: You picked the first one.\n- Second one\n\tNathan: You picked the second one.\n- Start again => start\n- End the conversation => END\nNathan: For more information see the online documentation.\n=> END",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_MULTILINE_TEXT,
	},

	MISSING_TRANSLATIONS_ARE_ERRORS: {
		value = false,
		type = TYPE_BOOL,
		is_advanced = true
	},
	INCLUDE_CHARACTERS_IN_TRANSLATABLE_STRINGS_LIST: {
		value = true,
		type = TYPE_BOOL,
	},
	UPDATE_POT_FILES_AUTOMATICALLY: {
		value = true,
		type = TYPE_BOOL,
		is_advanced = true
	},

	DIALOGUE_PROCESSOR_PATH: {
		value = "",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE,
		hint_string = "*.gd,*.cs",
		is_advanced = true
	},

	CUSTOM_TEST_SCENE_PATH: {
		value = preload("./test_scene.tscn").resource_path,
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE,
		is_advanced = true
	},
	EXTRA_AUTO_COMPLETE_SCRIPT_SOURCES: {
		value = [],
		type = TYPE_PACKED_STRING_ARRAY,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "%d/%d:*.*" % [TYPE_STRING, PROPERTY_HINT_FILE],
		is_advanced = true
	},

	BALLOON_PATH: {
		value = "",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE,
	},
	STATE_AUTOLOAD_SHORTCUTS: {
		value = [],
		type = TYPE_PACKED_STRING_ARRAY,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "%d:" % [TYPE_STRING],
	},
	WARN_ABOUT_METHOD_PROPERTY_OR_SIGNAL_NAME_CONFLICTS: {
		value = false,
		type = TYPE_BOOL,
		is_advanced = true
	},

	IGNORE_MISSING_STATE_VALUES: {
		value = false,
		type = TYPE_BOOL,
		is_advanced = true
	},
	USES_DOTNET: {
		value = false,
		type = TYPE_BOOL,
		is_hidden = true
	}
}


static func prepare() -> void:
	# Set up initial settings
	for key: String in SETTINGS_CONFIGURATION:
		var setting_config: Dictionary = SETTINGS_CONFIGURATION[key]
		var setting_name: String = "dialogue_manager/%s" % key
		if not ProjectSettings.has_setting(setting_name):
			ProjectSettings.set_setting(setting_name, setting_config.value)
		ProjectSettings.set_initial_value(setting_name, setting_config.value)
		ProjectSettings.add_property_info({
			"name" = setting_name,
			"type" = setting_config.type,
			"hint" = setting_config.get("hint", PROPERTY_HINT_NONE),
			"hint_string" = setting_config.get("hint_string", "")
		})
		ProjectSettings.set_as_basic(setting_name, not setting_config.has("is_advanced"))
		ProjectSettings.set_as_internal(setting_name, setting_config.has("is_hidden"))


static func set_setting(key: String, value: Variant) -> void:
	if get_setting(key, value) != value:
		ProjectSettings.set_setting("dialogue_manager/%s" % key, value)
		ProjectSettings.set_initial_value("dialogue_manager/%s" % key, SETTINGS_CONFIGURATION[key].value)
		ProjectSettings.save()


static func get_setting(key: String, default: Variant) -> Variant:
	if ProjectSettings.has_setting("dialogue_manager/%s" % key):
		return ProjectSettings.get_setting("dialogue_manager/%s" % key)
	else:
		return default


#endregion

#region User


static func get_user_config() -> Dictionary:
	var user_config: Dictionary = {
		check_for_updates = true,
		just_refreshed = null,
		recent_files = [],
		reopen_files = [],
		most_recent_reopen_file = "",
		file_meta = {},
		run_key = "",
		run_resource_path = "",
		is_running_test_scene = false,
		has_dotnet_solution = false,
		open_in_external_editor = false
	}

	if FileAccess.file_exists(DMConstants.USER_CONFIG_PATH):
		var file: FileAccess = FileAccess.open(DMConstants.USER_CONFIG_PATH, FileAccess.READ)
		user_config.merge(JSON.parse_string(file.get_as_text()), true)

	return user_config


static func save_user_config(user_config: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(DMConstants.USER_CONFIG_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(user_config))


static func set_user_value(key: String, value: Variant) -> void:
	var user_config: Dictionary = get_user_config()
	user_config[key] = value
	save_user_config(user_config)


static func get_user_value(key: String, default: Variant = null) -> Variant:
	return get_user_config().get(key, default)


static func forget_path(path: String) -> void:
	remove_recent_file(path)
	var file_meta: Dictionary = get_user_value("file_meta", {})
	file_meta.erase(path)
	set_user_value("file_meta", file_meta)


static func add_recent_file(path: String) -> void:
	var recent_files: Array = get_user_value("recent_files", [])
	if path in recent_files:
		recent_files.erase(path)
	recent_files.insert(0, path)
	set_user_value("recent_files", recent_files)


static func move_recent_file(from_path: String, to_path: String) -> void:
	var recent_files: Array = get_user_value("recent_files", [])
	for i: int in range(0, recent_files.size()):
		if recent_files[i] == from_path:
			recent_files[i] = to_path
	set_user_value("recent_files", recent_files)


static func remove_recent_file(path: String) -> void:
	var recent_files: Array = get_user_value("recent_files", [])
	if path in recent_files:
		recent_files.erase(path)
	set_user_value("recent_files", recent_files)


static func get_recent_files() -> Array:
	return get_user_value("recent_files", [])


static func clear_recent_files() -> void:
	set_user_value("recent_files", [])
	set_user_value("carets", {})


static func set_caret(path: String, cursor: Vector2) -> void:
	var file_meta: Dictionary = get_user_value("file_meta", {})
	file_meta[path] = file_meta.get(path, {}).merged({ cursor = "%d,%d" % [cursor.x, cursor.y] }, true)
	set_user_value("file_meta", file_meta)


static func get_caret(path: String) -> Vector2:
	var file_meta: Dictionary = get_user_value("file_meta", {})
	if file_meta.has(path):
		var cursor: PackedStringArray = file_meta.get(path).get("cursor", "0,0").split(",")
		return Vector2(cursor[0].to_int(), cursor[1].to_int())
	else:
		return Vector2.ZERO


static func set_scroll(path: String, scroll_vertical: float) -> void:
	var file_meta: Dictionary = get_user_value("file_meta", {})
	file_meta[path] = file_meta.get(path, {}).merged({ scroll_vertical = scroll_vertical }, true)
	set_user_value("file_meta", file_meta)


static func get_scroll(path: String) -> float:
	var file_meta: Dictionary = get_user_value("file_meta", {})
	if file_meta.has(path):
		return file_meta.get(path).get("scroll_vertical", 0)
	else:
		return 0


static func check_for_dotnet_solution() -> bool:
	if Engine.is_editor_hint():
		var has_dotnet_solution: bool = false
		if ProjectSettings.has_setting("dotnet/project/solution_directory"):
			var directory: String = ProjectSettings.get("dotnet/project/solution_directory")
			var file_name: String = ProjectSettings.get("dotnet/project/assembly_name")
			has_dotnet_solution = FileAccess.file_exists("res://%s/%s.sln" % [directory, file_name])
		set_setting(DMSettings.USES_DOTNET, has_dotnet_solution)
		return has_dotnet_solution

	return get_setting(DMSettings.USES_DOTNET, false)


#endregion

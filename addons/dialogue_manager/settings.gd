@tool
extends Node


const DialogueConstants = preload("./constants.gd")


### Editor config

const DEFAULT_SETTINGS = {
	states = [],
	missing_translations_are_errors = false,
	export_characters_in_translation = true,
	wrap_lines = false,
	new_with_template = true,
	include_all_responses = false,
	ignore_missing_state_values = false,
	custom_test_scene_path = preload("./test_scene.tscn").resource_path,
	default_csv_locale = "en",
	balloon_path = "",
	create_lines_for_responses_with_characters = true,
	include_character_in_translation_exports = false,
	include_notes_in_translation_exports = false
}


static func prepare() -> void:
	# Migrate previous keys
	for key in [
		"states",
		"missing_translations_are_errors",
		"export_characters_in_translation",
		"wrap_lines",
		"new_with_template",
		"include_all_responses",
		"custom_test_scene_path"
	]:
		if ProjectSettings.has_setting("dialogue_manager/%s" % key):
			var value = ProjectSettings.get_setting("dialogue_manager/%s" % key)
			ProjectSettings.set_setting("dialogue_manager/%s" % key, null)
			set_setting(key, value)

	# Set up initial settings
	for setting in DEFAULT_SETTINGS:
		var setting_name: String = "dialogue_manager/general/%s" % setting
		if not ProjectSettings.has_setting(setting_name):
			set_setting(setting, DEFAULT_SETTINGS[setting])
		ProjectSettings.set_initial_value(setting_name, DEFAULT_SETTINGS[setting])
		if setting.ends_with("_path"):
			ProjectSettings.add_property_info({
				"name": setting_name,
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_FILE,
			})

	ProjectSettings.save()


static func set_setting(key: String, value) -> void:
	ProjectSettings.set_setting("dialogue_manager/general/%s" % key, value)
	ProjectSettings.set_initial_value("dialogue_manager/general/%s" % key, DEFAULT_SETTINGS[key])
	ProjectSettings.save()


static func get_setting(key: String, default):
	if ProjectSettings.has_setting("dialogue_manager/general/%s" % key):
		return ProjectSettings.get_setting("dialogue_manager/general/%s" % key)
	else:
		return default


static func get_settings(only_keys: PackedStringArray = []) -> Dictionary:
	var settings: Dictionary = {}
	for key in DEFAULT_SETTINGS.keys():
		if only_keys.is_empty() or key in only_keys:
			settings[key] = get_setting(key, DEFAULT_SETTINGS[key])
	return settings


### User config


static func get_user_config() -> Dictionary:
	var user_config: Dictionary = {
		check_for_updates = true,
		just_refreshed = null,
		recent_files = [],
		reopen_files = [],
		most_recent_reopen_file = "",
		carets = {},
		run_title = "",
		run_resource_path = "",
		is_running_test_scene = false,
		has_dotnet_solution = false,
		open_in_external_editor = false
	}

	if FileAccess.file_exists(DialogueConstants.USER_CONFIG_PATH):
		var file: FileAccess = FileAccess.open(DialogueConstants.USER_CONFIG_PATH, FileAccess.READ)
		user_config.merge(JSON.parse_string(file.get_as_text()), true)

	return user_config


static func save_user_config(user_config: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(DialogueConstants.USER_CONFIG_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(user_config))


static func set_user_value(key: String, value) -> void:
	var user_config: Dictionary = get_user_config()
	user_config[key] = value
	save_user_config(user_config)


static func get_user_value(key: String, default = null):
	return get_user_config().get(key, default)


static func add_recent_file(path: String) -> void:
	var recent_files: Array = get_user_value("recent_files", [])
	if path in recent_files:
		recent_files.erase(path)
	recent_files.insert(0, path)
	set_user_value("recent_files", recent_files)


static func move_recent_file(from_path: String, to_path: String) -> void:
	var recent_files: Array = get_user_value("recent_files", [])
	for i in range(0, recent_files.size()):
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
	var carets: Dictionary = get_user_value("carets", {})
	carets[path] = {
		x = cursor.x,
		y = cursor.y
	}
	set_user_value("carets", carets)


static func get_caret(path: String) -> Vector2:
	var carets = get_user_value("carets", {})
	if carets.has(path):
		var caret = carets.get(path)
		return Vector2(caret.x, caret.y)
	else:
		return Vector2.ZERO


static func has_dotnet_solution() -> bool:
	if get_user_value("has_dotnet_solution", false): return true

	if ProjectSettings.has_setting("dotnet/project/solution_directory"):
		var directory: String = ProjectSettings.get("dotnet/project/solution_directory")
		var file_name: String = ProjectSettings.get("dotnet/project/assembly_name")
		var has_dotnet_solution: bool = FileAccess.file_exists("res://%s/%s.sln" % [directory, file_name])
		set_user_value("has_dotnet_solution", has_dotnet_solution)
		return has_dotnet_solution

	return false

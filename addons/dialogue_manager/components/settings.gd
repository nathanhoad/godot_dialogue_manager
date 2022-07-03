tool
extends Node


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


var config := ConfigFile.new()


func _ready() -> void:
	config.load(DialogueConstants.CONFIG_PATH)
	if not config.has_section("editor"):
		config.set_value("editor", "check_for_errors", true)
		config.set_value("editor", "missing_translations_are_errors", false)
		config.set_value("editor", "store_compiler_results", true)
		config.set_value("editor", "continue_through_titles", false)
	if not config.has_section("runtime"):
		config.set_value("runtime", "include_all_responses", false)
		config.set_value("runtime", "states", [])


func reset_config() -> void:
	var dir = Directory.new()
	dir.remove(DialogueConstants.CONFIG_PATH)


func has_editor_value(key: String) -> bool:
	return config.has_section_key("editor", key)


func set_editor_value(key: String, value) -> void:
	config.set_value("editor", key, value)
	config.save(DialogueConstants.CONFIG_PATH)


func get_editor_value(key: String, default = null):
	return config.get_value("editor", key, default)


func has_runtime_value(key: String) -> bool:
	return config.has_section_key("runtime", key)


func set_runtime_value(key: String, value) -> void:
	config.set_value("runtime", key, value)
	config.save(DialogueConstants.CONFIG_PATH)


func get_runtime_value(key: String, default = null):
	return config.get_value("runtime", key, default)

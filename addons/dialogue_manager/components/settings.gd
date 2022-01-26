tool
extends Node


const Constants = preload("res://addons/dialogue_manager/constants.gd")


var config := ConfigFile.new()


func _ready() -> void:
	config.load(Constants.CONFIG_PATH)


func reset_config() -> void:
	var dir = Directory.new()
	dir.remove(Constants.CONFIG_PATH)


func has_editor_value(key: String) -> bool:
	return config.has_section_key("editor", key)


func set_editor_value(key: String, value) -> void:
	config.set_value("editor", key, value)
	config.save(Constants.CONFIG_PATH)


func get_editor_value(key: String, default = null):
	return config.get_value("editor", key, default)


func has_runtime_value(key: String) -> bool:
	return config.has_section_key("runtime", key)


func set_runtime_value(key: String, value) -> void:
	config.set_value("runtime", key, value)
	config.save(Constants.CONFIG_PATH)


func get_runtime_value(key: String, default = null):
	return config.get_value("runtime", key, default)

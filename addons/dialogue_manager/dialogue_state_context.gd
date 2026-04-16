@tool

@icon("uid://c22t5famre1yo")

class_name DialogueStateContext extends Node


@export var alias: String = "":
	set(value):
		alias = value
		update_configuration_warnings()
	get:
		return alias

@export var target: Node:
	set(value):
		target = value
		update_configuration_warnings()
	get:
		return target


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		DialogueManager.register_state_context(alias, target)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		DialogueManager.unregister_state_context(alias)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if alias.is_empty():
		warnings.append(DMConstants.translate("Alias cannot be empty."))

	if target == null:
		warnings.append(DMConstants.translate("Target cannot be null."))

	return warnings

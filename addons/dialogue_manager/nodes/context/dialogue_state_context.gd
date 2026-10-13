@tool

@icon("uid://c22t5famre1yo")

## Add a [DialogueStateContext] to a scene to expose a node (usually the base node) to dialogue.
class_name DialogueStateContext extends Node


## The name used in dialogue to refer to the exposed target node.
@export var alias: String = "":
	set(value):
		alias = value
		update_configuration_warnings()
	get:
		return alias

## The target who's values are exposed to dialogue.
@export var target: Node:
	set(value):
		target = value
		update_configuration_warnings()
	get:
		return target


func _enter_tree() -> void:
	if Engine.is_editor_hint(): return

	var dialogue_manager: Node = _get_dialogue_manager()
	if is_instance_valid(dialogue_manager):
		# Register straight away in case some dialogue starts on this same frame.
		dialogue_manager.register_state_context(alias, target)
	else:
		# The DialogueManager autoload isn't in the tree yet (this node is probably inside an
		# autoload that comes before it) so register as soon as it is.
		(func() -> void:
			var deferred_dialogue_manager: Node = _get_dialogue_manager()
			if is_instance_valid(deferred_dialogue_manager):
				deferred_dialogue_manager.register_state_context(alias, target)
		).call_deferred()


func _exit_tree() -> void:
	if Engine.is_editor_hint(): return

	var dialogue_manager: Node = _get_dialogue_manager()
	if is_instance_valid(dialogue_manager):
		dialogue_manager.unregister_state_context(alias)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if alias.is_empty():
		warnings.append(DMConstants.translate("Alias cannot be empty."))

	if target == null:
		warnings.append(DMConstants.translate("Target cannot be null."))

	return warnings


# Find the DialogueManager autoload. It registers itself as a singleton in its "_ready" so it
# might need to be fetched out of the scene tree if it hasn't gotten there yet.
func _get_dialogue_manager() -> Node:
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager") as Node

	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"DialogueManager")

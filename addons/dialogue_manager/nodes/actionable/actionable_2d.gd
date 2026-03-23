@tool

@icon("./actionable_2d.svg")

## A special [Area2D] node to hold information about starting dialogue.
##
## Assuming [code]dialogue_resource[/code] and [code]cue[/code] have been configured you can
## call [code]action()[/code] on this node at runtime to start dialogue.
class_name Actionable2D extends Area2D


## Emitted when this [Actionable2D] has [code]action()[/code] called on it.
signal actioned()


## The [DialogueResource] to use when starting dialogue.
@export var dialogue_resource: DialogueResource = null:
	set(value):
		dialogue_resource = value
		if dialogue_resource == null:
			dialogue_cue = ""
		notify_property_list_changed()
	get:
		return dialogue_resource

## The target cue to start dialogue from.
var dialogue_cue: String = ""

## The dialogue balloon that was last used by calling [code]action()[/code] (if there was one).
var dialogue_balloon: Node

## The method used to start dialogue action [code]action()[/code] is called. Override if you need
## different logic.
static var start_dialogue: Callable = func(p_dialogue_resource: DialogueResource, from_cue: String, extra_game_states: Array) -> Node2D:
	return DialogueManager.show_dialogue_balloon(p_dialogue_resource, from_cue, extra_game_states)


func _ready() -> void:
	add_to_group("dialogue_actionables")


#region Public


## Action this [Actionable2D]. If a [DialogueResource] and cue have been set on this node then
## it will start dialogue.
func action() -> void:
	if is_instance_valid(dialogue_resource) and not dialogue_cue.is_empty():
		dialogue_balloon = start_dialogue.call(dialogue_resource, dialogue_cue, [owner])
	actioned.emit()


## Find the nearest [Actionable2D] to a given position.
static func get_nearest_actionable_to(target_position: Vector2) -> Actionable2D:
	var nearest_distance: float = INF
	var nearest_actionable: Actionable2D = null
	var actionables: Array[Node] = (Engine.get_main_loop() as SceneTree).get_nodes_in_group("dialogue_actionables")
	for actionable: Actionable2D in actionables:
		var distance: float = actionable.global_position.distance_squared_to(target_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_actionable = actionable

	return nearest_actionable


#endregion

#region Properties


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	if is_instance_valid(dialogue_resource):
		props.append({
			name = "dialogue_cue",
			type = TYPE_STRING
		})

	return props


func _get(property: StringName) -> Variant:
	match property:
		"dialogue_cue":
			return dialogue_cue

	return null


func _set(property: StringName, value: Variant) -> bool:
	match property:
		"dialogue_cue":
			dialogue_cue = value
			notify_property_list_changed()
			return true

	return false


func _property_can_revert(property: StringName) -> bool:
	match property:
		"dialogue_cue":
			return true

	return false


func _property_get_revert(property: StringName) -> Variant:
	match property:
		"dialogue_cue":
			return ""

	return null


#endregion

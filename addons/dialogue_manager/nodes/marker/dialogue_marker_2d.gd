@icon("uid://cim0y62o6g36i")

## A special marker node that helps locate the in-world representation of the speaking character.
## Generally, you would position a [DialogueMaker2D] at the mouth of the character and use
## its location as the origin of a speech balloon.
class_name DialogueMarker2D extends Marker2D


## The name of the character that owns this marker.
@export var character_name: String = ""


#region Static

## Get all [DialogueMarker2D] nodes.
static func all() -> Array[DialogueMarker2D]:
	var markers: Array[DialogueMarker2D] = []
	for node: DialogueMarker2D in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("2d_dialogue_markers"):
		markers.append(node)
	return markers


## Find a marker with a given character name.
static func find_for_character(target_character_name: String) -> DialogueMarker2D:
	for marker: DialogueMarker2D in all():
		if marker.character_name == target_character_name:
			return marker
	return null


#endregion


func _ready() -> void:
	add_to_group("2d_dialogue_markers")


#region Helpers


## Get the marker's position relative to the viewport.
func get_position_in_viewport() -> Vector2:
	return get_global_transform_with_canvas().origin


#endregion

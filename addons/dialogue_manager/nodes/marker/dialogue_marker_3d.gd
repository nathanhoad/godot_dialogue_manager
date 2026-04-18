@icon("uid://bo1hdyjmnjdql")

## A special marker node that helps locate the in-world representation of the speaking character.
## Generally, you would position a [DialogueMaker3D] at the mouth of the character and use
## its location as the origin of a speech balloon.
class_name DialogueMarker3D extends Marker3D


## The name of the character that owns this marker.
@export var character_name: String = ""


#region Static

## Get all [DialogueMarker3D] nodes.
static func all() -> Array[DialogueMarker3D]:
	var markers: Array[DialogueMarker3D] = []
	for node: DialogueMarker3D in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("3d_dialogue_markers"):
		markers.append(node)
	return markers


## Find a marker with a given character name.
static func find_for_character(target_character_name: String) -> DialogueMarker3D:
	for marker: DialogueMarker3D in all():
		if marker.character_name == target_character_name:
			return marker
	return null


#endregion


func _ready() -> void:
	add_to_group("3d_dialogue_markers")


#region Helpers


## Get the marker's position relative to the viewport.
func get_position_in_viewport() -> Vector2:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		return camera.unproject_position(global_position)
	else:
		return Vector2.ZERO


#endregion

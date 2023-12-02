extends Node


var some_property: int = 0
var character_name: String = "Coco"


func some_method(number: int, string: String) -> int:
	return number * string.length()


func long_mutation() -> void:
	await get_tree().create_timer(0.2).timeout

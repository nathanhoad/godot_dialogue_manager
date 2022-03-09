extends Node


var prompt: String
var translation_key: String
var replacements: Array
var next_id: String


func _init(data: Dictionary, should_translate: bool = true) -> void:
	prompt = tr(data.get("translation_key")) if should_translate else data.get("text")
	translation_key = data.get("translation_key")
	replacements = data.get("replacements")
	next_id = data.get("next_id")

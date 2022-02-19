extends Node


var prompt: String
var replacements: Array
var next_id: String
var translation_key : String


func _init(data: Dictionary, should_translate: bool = true) -> void:
	prompt = tr(data.get("text")) if should_translate else data.get("text")
	replacements = data.get("replacements")
	next_id = data.get("next_id")
	translation_key = data['translation_key']

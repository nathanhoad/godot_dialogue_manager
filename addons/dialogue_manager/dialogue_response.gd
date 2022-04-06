extends Node


var character: String
var character_replacements: Array
var is_allowed: bool
var prompt: String
var translation_key: String
var replacements: Array
var next_id: String


func _init(data: Dictionary, should_translate: bool = true) -> void:
	character = data.get("character", "")
	character_replacements = data.get("character_replacements", [])
	is_allowed = data.get("is_allowed", true)
	prompt = tr(data.get("translation_key")) if should_translate else data.get("text")
	translation_key = data.get("translation_key")
	replacements = data.get("replacements", [])
	next_id = data.get("next_id")

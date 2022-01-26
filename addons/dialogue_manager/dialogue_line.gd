extends Node

const Constants = preload("res://addons/dialogue_manager/constants.gd")

var type: String = Constants.TYPE_DIALOGUE
var next_id: String

var mutation: Dictionary

var character: String
var dialogue: String
var replacements: Array

var responses: Array = []


func _init(data: Dictionary, should_translate: bool = true) -> void:
	type = data.get("type")
	next_id = data.get("next_id")
	
	match data.get("type"):
		Constants.TYPE_DIALOGUE:
			character = data.get("character")
			dialogue = tr(data.get("text")) if should_translate else data.get("text")
			replacements = data.get("replacements", [])
			
		Constants.TYPE_MUTATION:
			mutation = data.get("mutation")

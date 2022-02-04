extends Node

const Constants = preload("res://addons/dialogue_manager/constants.gd")

var dialogue_manager

var type: String = Constants.TYPE_DIALOGUE
var next_id: String

var mutation: Dictionary

var character: String
var dialogue: String
var replacements: Array

var responses: Array = []

var pauses: Dictionary = {}
var speeds: Array = []
var inline_mutations: Array = []


func _init(data: Dictionary, should_translate: bool = true) -> void:
	type = data.get("type")
	next_id = data.get("next_id")
	
	match data.get("type"):
		Constants.TYPE_DIALOGUE:
			character = data.get("character")
			dialogue = tr(data.get("text")) if should_translate else data.get("text")
			replacements = data.get("replacements", [])
			pauses = data.get("pauses", {})
			speeds = data.get("speeds", [])
			inline_mutations = data.get("inline_mutations", [])
			
		Constants.TYPE_MUTATION:
			mutation = data.get("mutation")


func get_pause(index: int) -> float:
	return pauses.get(index, 0)


func get_speed(index: int) -> float:
	var speed = 1
	for s in speeds:
		if s[0] > index:
			return speed
		speed = s[1]
	return speed


func mutate_inline_mutations(index: int) -> void:
	for inline_mutation in inline_mutations:
		if inline_mutation[0] > index:
			return
		if inline_mutation[0] == index:
			dialogue_manager.mutate(inline_mutations[0])

extends Node

const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueParser = preload("res://addons/dialogue_manager/components/parser.gd")

var dialogue_manager

var type: String = DialogueConstants.TYPE_DIALOGUE
var next_id: String
var translation_key: String

var mutation: Dictionary

var character: String
var character_replacements: Array
var dialogue: String
var replacements: Array

var responses: Array = []

var pauses: Dictionary = {}
var speeds: Array = []
var inline_mutations: Array = []

var time = null


func _init(data: Dictionary, should_translate: bool = true, manager = null) -> void:
	dialogue_manager = manager
	
	type = data.get("type")
	next_id = data.get("next_id")
	
	match data.get("type"):
		DialogueConstants.TYPE_DIALOGUE:
			# Our bbcodes need to be process after text has been resolved so that the markers are at the correct index
			var text = dialogue_manager.get_with_replacements(tr(data.get("translation_key")) if should_translate else data.get("text"), data.get("replacements"))
			var parser = DialogueParser.new()
			var markers = parser.extract_markers(text)
			parser.free()
			
			character = data.get("character")
			character_replacements = data.get("character_replacements", [])
			dialogue = markers.get("text")
			translation_key = data.get("translation_key")
			replacements = data.get("replacements", [])
			pauses = markers.get("pauses")
			speeds = markers.get("speeds")
			inline_mutations = markers.get("mutations")
			time = markers.get("time")
			
		DialogueConstants.TYPE_MUTATION:
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
		# inline mutations are an array of arrays in the form of [character index, resolvable function]
		if inline_mutation[0] > index:
			return
		if inline_mutation[0] == index:
			dialogue_manager.mutate(inline_mutation[1])

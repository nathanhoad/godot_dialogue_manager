class_name DialogueLine extends RefCounted


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueResponse = preload("res://addons/dialogue_manager/dialogue_response.gd")


var type: String = DialogueConstants.TYPE_DIALOGUE
var next_id: String = ""
var character: String = ""
var character_replacements: Array[Dictionary] = []
var text: String = ""
var text_replacements: Array[Dictionary] = []
var translation_key: String = ""
var pauses: Dictionary = {}
var speeds: Dictionary = {}
var inline_mutations: Array[Array] = []
var responses: Array[DialogueResponse] = []
var extra_game_states: Array = []
var time = null
var mutation: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	if data.size() > 0:
		next_id = data.next_id
		type = data.type
		extra_game_states = data.extra_game_states
		
		match type:
			DialogueConstants.TYPE_DIALOGUE:
				character = data.character
				character_replacements = data.character_replacements
				text = data.text
				text_replacements = data.text_replacements
				translation_key = data.translation_key
				pauses = data.pauses
				speeds = data.speeds
				inline_mutations = data.inline_mutations
				time = data.time
			
			DialogueConstants.TYPE_MUTATION:
				mutation = data.mutation


# Get the pause for the current typing position if there is one
func get_pause(at_index: int) -> float:
	return pauses.get(at_index, 0)


# Get the speed for the current typing position
func get_speed(at_index: int) -> float:
	var speed: float = 1
	for index in speeds:
		if index > at_index:
			return speed
		speed = speeds[index]
	return speed


# Run any mutations at the current typing position
func mutate_inline_mutations(index: int) -> void:
	for inline_mutation in inline_mutations:
		# inline mutations are an array of arrays in the form of [character index, resolvable function]
		if inline_mutation[0] > index:
			return
		if inline_mutation[0] == index:
			# The DialogueManager can't be referenced directly here so we need to get it by its path
			Engine.get_singleton("DialogueManager").mutate(inline_mutation[1], extra_game_states)

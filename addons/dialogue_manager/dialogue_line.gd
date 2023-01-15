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
var inline_mutations: Array[Dictionary] = []
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
				

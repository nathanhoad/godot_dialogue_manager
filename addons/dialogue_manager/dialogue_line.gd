## A line of dialogue returned from [code]DialogueManager[/code].
class_name DialogueLine extends RefCounted


const _DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


## The internal type of this dialogue object. One of [code]TYPE_DIALOGUE[/code] or [code]TYPE_MUTATION[/code]
var type: String = _DialogueConstants.TYPE_DIALOGUE

## The next line ID after this line.
var next_id: String = ""

## The character name that is saying this line.
var character: String = ""

## A dictionary of variable replacements fo the character name. Generally for internal use only.
var character_replacements: Array[Dictionary] = []

## The dialogue being spoken.
var text: String = ""

## A dictionary of replacements for the text. Generally for internal use only.
var text_replacements: Array[Dictionary] = []

## The key to use for translating this line.
var translation_key: String = ""

## A map for when and for how long to pause while typing out the dialogue text.
var pauses: Dictionary = {}

## A map for speed changes when typing out the dialogue text.
var speeds: Dictionary = {}

## A map of any mutations to run while typing out the dialogue text.
var inline_mutations: Array[Array] = []

## A list of responses attached to this line of dialogue.
var responses: Array[DialogueResponse] = []

## A list of any extra game states to check when resolving variables and mutations.
var extra_game_states: Array = []

## How long to show this line before advancing to the next. Either a float (of seconds), [code]"auto"[/code], or [code]null[/code].
var time = null

## The mutation details if this is a mutation line (where [code]type == TYPE_MUTATION[/code]).
var mutation: Dictionary = {}

## The conditions to check before including this line in the flow of dialogue. If failed the line will be skipped over.
var conditions: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	if data.size() > 0:
		next_id = data.next_id
		type = data.type
		extra_game_states = data.extra_game_states

		match type:
			_DialogueConstants.TYPE_DIALOGUE:
				character = data.character
				character_replacements = data.character_replacements
				text = data.text
				text_replacements = data.text_replacements
				translation_key = data.translation_key
				pauses = data.pauses
				speeds = data.speeds
				inline_mutations = data.inline_mutations
				conditions = data.conditions
				time = data.time

			_DialogueConstants.TYPE_MUTATION:
				mutation = data.mutation


func _to_string() -> String:
	match type:
		_DialogueConstants.TYPE_DIALOGUE:
			return "<DialogueLine character=\"%s\" text=\"%s\">" % [character, text]
		_DialogueConstants.TYPE_MUTATION:
			return "<DialogueLine mutation>"
	return ""

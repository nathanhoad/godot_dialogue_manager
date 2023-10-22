## A response to a line of dialogue, usualy attached to a [code]DialogueLine[/code].
class_name DialogueResponse extends RefCounted


const _DialogueConstants = preload("./constants.gd")


## The ID of this response
var id: String

## The internal type of this dialogue object, always set to [code]TYPE_RESPONSE[/code].
var type: String = _DialogueConstants.TYPE_RESPONSE

## The next line ID to use if this response is selected by the player.
var next_id: String = ""

## [code]true[/code] if the condition of this line was met.
var is_allowed: bool = true

## The prompt for this response.
var text: String = ""

## A dictionary of variable replaces for the text. Generally for internal use only.
var text_replacements: Array[Dictionary] = []

## Any #tags
var tags: PackedStringArray = []

## The key to use for translating the text.
var translation_key: String = ""


func _init(data: Dictionary = {}) -> void:
	if data.size() > 0:
		id = data.id
		type = data.type
		next_id = data.next_id
		is_allowed = data.is_allowed
		text = data.text
		text_replacements = data.text_replacements
		tags = data.tags
		translation_key = data.translation_key


func _to_string() -> String:
	return "<DialogueResponse text=\"%s\">" % text

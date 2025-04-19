## A response to a line of dialogue, usualy attached to a [code]DialogueLine[/code].
class_name DialogueResponse extends RefCounted


## The ID of this response
var id: String

## The internal type of this dialogue object, always set to [code]TYPE_RESPONSE[/code].
var type: String = DMConstants.TYPE_RESPONSE

## The next line ID to use if this response is selected by the player.
var next_id: String = ""

## [code]true[/code] if the condition of this line was met.
var is_allowed: bool = true

## The original condition text.
var condition_as_text: String = ""

## A character (depending on the "characters in responses" behaviour setting).
var character: String = ""

## A dictionary of varialbe replaces for the character name. Generally for internal use only.
var character_replacements: Array[Dictionary] = []

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
		character = data.character
		character_replacements = data.character_replacements
		text = data.text
		text_replacements = data.text_replacements
		tags = data.tags
		translation_key = data.translation_key
		condition_as_text = data.condition_as_text


func _to_string() -> String:
	return "<DialogueResponse text=\"%s\">" % text


func get_tag_value(tag_name: String) -> String:
	var wrapped := "%s=" % tag_name
	for t in tags:
		if t.begins_with(wrapped):
			return t.replace(wrapped, "").strip_edges()
	return ""

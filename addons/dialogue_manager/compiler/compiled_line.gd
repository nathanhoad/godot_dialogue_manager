## A compiled line of dialogue.
class_name DMCompiledLine extends RefCounted


## The ID of the line
var id: String
## The translation key (or static line ID).
var translation_key: String = ""
## The type of line.
var type: String = ""
## The character name.
var character: String = ""
## Any interpolation expressions for the character name.
var character_replacements: Array[Dictionary] = []
## The text of the line.
var text: String = ""
## Any interpolation expressions for the text.
var text_replacements: Array[Dictionary] = []
## Any response siblings associated with this line.
var responses: PackedStringArray = []
## Any randomise or case siblings for this line.
var siblings: Array[Dictionary] = []
## Any lines said simultaneously.
var concurrent_lines: PackedStringArray = []
## Any tags on this line.
var tags: PackedStringArray = []
## The condition or mutation expression for this line.
var expression: Dictionary = {}
## The next sequential line to go to after this line.
var next_id: String = ""
## The next line to go to after this line if it is unknown and compile time.
var next_id_expression: Array[Dictionary] = []
## Whether this jump line should return after the jump target sequence has ended.
var is_snippet: bool = false
## The ID of the next sibling line.
var next_sibling_id: String = ""
## The ID after this line if it belongs to a block (eg. conditions).
var next_id_after: String = ""
## Any doc comments attached to this line.
var notes: String = ""


#region Hooks


func _init(initial_id: String, initial_type: String) -> void:
	id = initial_id
	type = initial_type


func _to_string() -> String:
	var s: Array = [
		"[%s]" % [type],
		"%s:" % [character] if character != "" else null,
		text if text != "" else null,
		expression if expression.size() > 0 else null,
		"[%s]" % [",".join(tags)] if tags.size() > 0 else null,
		str(siblings) if siblings.size() > 0 else null,
		str(responses) if responses.size() > 0 else null,
		"=> END" if "end" in next_id else "=> %s" % [next_id],
		"(~> %s)" % [next_sibling_id] if next_sibling_id != "" else null,
		"(==> %s)" % [next_id_after] if next_id_after != "" else null,
	].filter(func(item): return item != null)

	return " ".join(s)


#endregion

#region Helpers


## Express this line as a [Dictionary] that can be stored in a resource.
func to_data() -> Dictionary:
	var d: Dictionary = {
		id = id,
		type = type,
		next_id = next_id
	}

	if next_id_expression.size() > 0:
		d.next_id_expression = next_id_expression

	match type:
		DMConstants.TYPE_CONDITION:
			d.condition = expression
			if not next_sibling_id.is_empty():
				d.next_sibling_id = next_sibling_id
			d.next_id_after = next_id_after

		DMConstants.TYPE_WHILE:
			d.condition = expression
			d.next_id_after = next_id_after

		DMConstants.TYPE_MATCH:
			d.condition = expression
			d.next_id_after = next_id_after
			d.cases = siblings

		DMConstants.TYPE_MUTATION:
			d.mutation = expression

		DMConstants.TYPE_GOTO:
			d.is_snippet = is_snippet
			d.next_id_after = next_id_after
			if not siblings.is_empty():
				d.siblings = siblings

		DMConstants.TYPE_RANDOM:
			d.siblings = siblings

		DMConstants.TYPE_RESPONSE:
			d.text = text

			if not responses.is_empty():
				d.responses = responses

			if translation_key != text:
				d.translation_key = translation_key
			if not expression.is_empty():
				d.condition = expression
			if not character.is_empty():
				d.character = character
			if not character_replacements.is_empty():
				d.character_replacements = character_replacements
			if not text_replacements.is_empty():
				d.text_replacements = text_replacements
			if not tags.is_empty():
				d.tags = tags
			if not notes.is_empty():
				d.notes = notes

		DMConstants.TYPE_DIALOGUE:
			d.text = text

			if translation_key != text:
				d.translation_key = translation_key

			if not character.is_empty():
				d.character = character
			if not character_replacements.is_empty():
				d.character_replacements = character_replacements
			if not text_replacements.is_empty():
				d.text_replacements = text_replacements
			if not tags.is_empty():
				d.tags = tags
			if not notes.is_empty():
				d.notes = notes
			if not siblings.is_empty():
				d.siblings = siblings
			if not concurrent_lines.is_empty():
				d.concurrent_lines = concurrent_lines

	return d


#endregion

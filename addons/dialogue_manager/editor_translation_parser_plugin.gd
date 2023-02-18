extends EditorTranslationParserPlugin


const DialogueParser = preload("res://addons/dialogue_manager/components/parser.gd")
const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


func _parse_file(path: String, msgids: Array, msgids_context_plural: Array) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	
	var parser = DialogueParser.new()
	parser.parse(text)
	var dialogue = parser.get_data().lines
	parser.free()
	
	var known_keys: PackedStringArray = PackedStringArray([])
	
	var translatable_lines: Dictionary = {}
	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)
		
		if not line.type in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]: continue
		if line.translation_key in known_keys: continue
		
		known_keys.append(line.translation_key)
		
		msgids_context_plural.append([line.translation_key, line.text, ""])


func _get_recognized_extensions() -> PackedStringArray:
	return ["dialogue"]

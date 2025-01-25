class_name DMTranslationParserPlugin extends EditorTranslationParserPlugin


func _parse_file(path: String, msgids: Array, msgids_context_plural: Array) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()

	var data: DMCompilerResult = DMCompiler.compile_string(text, path)
	var known_keys: PackedStringArray = PackedStringArray([])

	# Add all character names if settings ask for it
	if DMSettings.get_setting(DMSettings.INCLUDE_CHARACTERS_IN_TRANSLATABLE_STRINGS_LIST, true):
		var character_names: PackedStringArray = data.character_names
		for character_name in character_names:
			if character_name in known_keys: continue

			known_keys.append(character_name)

			msgids_context_plural.append([character_name.replace('"', '\"'), "dialogue", ""])

	# Add all dialogue lines and responses
	var dialogue: Dictionary = data.lines
	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)

		if not line.type in [DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RESPONSE]: continue
		if line.translation_key in known_keys: continue

		known_keys.append(line.translation_key)

		if line.translation_key == "" or line.translation_key == line.text:
			msgids_context_plural.append([line.text.replace('"', '\"'), "", ""])
		else:
			msgids_context_plural.append([line.text.replace('"', '\"'), line.translation_key.replace('"', '\"'), ""])


func _get_recognized_extensions() -> PackedStringArray:
	return ["dialogue"]

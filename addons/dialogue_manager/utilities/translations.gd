## A collection of utility functions for working with dialogue translations.
class_name DMTranslationUtilities extends RefCounted


## Generate translation keys from some text.
static func generate_translation_keys() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	for file_path: String in DMCache.get_files():
		var text: String = FileAccess.get_file_as_string(file_path)

		var lines: PackedStringArray = text.split("\n")
		var compiled_lines: Dictionary = DMCompiler.compile_string(text, "").lines

		# Add in any that are missing
		for i in lines.size():
			var line = lines[i]
			var l = line.strip_edges()

			if not [DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RESPONSE].has(DMCompiler.get_line_type(l)): continue
			if not compiled_lines.has(str(i)): continue

			if "[ID:" in line: continue

			var translatable_text: String = ""
			if l.begins_with("- "):
				translatable_text = DMCompiler.extract_translatable_string(l)
			else:
				translatable_text = l.substr(l.find(":") + 1)

			var key: String = _generate_id(file_path)
			while key in DMCache.known_static_ids:
				key = _generate_id(file_path)
			line = line.replace("\\n", "!NEWLINE!")
			translatable_text = translatable_text.replace("\n", "!NEWLINE!")
			lines[i] = line.replace(translatable_text, translatable_text + " [ID:%s]" % [key]).replace("!NEWLINE!", "\\n")

			DMCache.known_static_ids[key] = file_path

		text = "\n".join(lines)

		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string(text)
		file.close()


## Get a random-ish ID for a line.
static func _generate_id(file_path: String) -> String:
	return ResourceUID.path_to_uid(file_path).replace("uid://", "") + "_" + str(randi() % 1000000).sha1_text().substr(0, 6)

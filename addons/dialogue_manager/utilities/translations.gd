## A collection of utility functions for working with dialogue translations.
class_name DMTranslationUtilities extends RefCounted


## Generate static IDs/translation keys from some text.
static func generate_static_line_ids_for_project() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	for file_path: String in DMCache.get_files():
		var text: String = FileAccess.get_file_as_string(file_path)

		text = generate_static_line_ids_for_text(text, file_path)

		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string(text)
		file.close()


## Generate static line IDs for some text.
static func generate_static_line_ids_for_text(text: String, file_path: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var compiled_lines: Dictionary = DMCompiler.compile_string(text, "").lines

	# Add in any that are missing
	for i: int in lines.size():
		var line: String = lines[i]
		var l: String = line.strip_edges()

		if not [DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RESPONSE].has(DMCompiler.get_line_type(l)): continue
		if not compiled_lines.has(str(i)): continue

		if "[ID:" in line: continue

		var translatable_text: String = ""
		if l.begins_with("- "):
			translatable_text = DMCompiler.extract_translatable_string(l)
		else:
			translatable_text = Array(l.replace("\\:", "!ESCAPED_COLON!").split(":")).back().replace("!ESCAPED_COLON!", "\\:")

		var key: String = _generate_id(file_path)
		while key in DMCache.known_static_ids:
			key = _generate_id(file_path)

		line = line.replace("\\n", "!NEWLINE!")
		translatable_text = translatable_text.replace("\\n", "!NEWLINE!")
		lines[i] = line.replace(translatable_text, translatable_text + " [ID:%s]" % [key]).replace("!NEWLINE!", "\\n")

		DMCache.known_static_ids[key] = file_path

	return "\n".join(lines)


## Get a random-ish ID for a line.
static func _generate_id(file_path: String) -> String:
	return ResourceUID.path_to_uid(file_path).replace("uid://", "") + "_" + str(randi() % 1000000).sha1_text().substr(0, 6)


## Export the dialogue and responses of every dialogue file in the project to a single CSV.
static func export_all_translations_to_csv(to_path: String, default_locale: String, default_delimiter: String, include_character_names: bool, include_notes: bool) -> void:
	var file: FileAccess

	# If the file exists, read it first so we can keep any translations that are already in it and match its existing column layout
	var existing_csv: Dictionary = {}
	var headings: PackedStringArray = []
	var delimiter: String = get_delimiter_for_csv(to_path, default_delimiter)
	var column_count: int = 2
	var default_locale_column: int = 1
	var character_column: int = -1
	var notes_column: int = -1
	if FileAccess.file_exists(to_path):
		file = FileAccess.open(to_path, FileAccess.READ)
		var is_first_line: bool = true
		var line: Array
		while !file.eof_reached():
			line = file.get_csv_line(delimiter)
			if is_first_line:
				is_first_line = false
				headings = PackedStringArray(line)
				column_count = line.size()
				for i: int in range(1, line.size()):
					if line[i] == default_locale:
						default_locale_column = i
					elif line[i] == "_character":
						character_column = i
					elif line[i] == "_notes":
						notes_column = i
				continue

			# Make sure the line isn't empty before adding it
			if line.size() > 0 and line[0].strip_edges() != "":
				existing_csv[line[0]] = line
		file.close()

	# If there wasn't an existing file then start a fresh heading row
	if headings.is_empty():
		headings = ["keys", default_locale]
		column_count = headings.size()

	# Add the optional columns if their settings are turned on but they aren't in the file yet
	if character_column == -1 and include_character_names:
		character_column = column_count
		column_count += 1
		headings.append("_character")
	if notes_column == -1 and include_notes:
		notes_column = column_count
		column_count += 1
		headings.append("_notes")

	# Gather every translatable line from every dialogue file in the project. Files are processed in a stable (sorted)
	# order and their lines are kept in source order, so editing one file only ever changes that file's section of the
	# CSV instead of shuffling rows around.
	var files: Array = Array(DMCache.get_files())
	files.sort()

	var known_keys: PackedStringArray = []
	var lines_to_save: Array = []
	for file_path: String in files:
		var dialogue: Dictionary = DMCompiler.compile_string(FileAccess.get_file_as_string(file_path), file_path).lines
		for key: String in dialogue.keys():
			var line: Dictionary = dialogue.get(key)

			if not line.type in [DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RESPONSE]: continue

			var translation_key: String = line.get(&"translation_key", line.text)

			if translation_key in known_keys: continue

			known_keys.append(translation_key)

			var line_to_save: PackedStringArray = []
			if existing_csv.has(translation_key):
				line_to_save = existing_csv.get(translation_key)
				line_to_save.resize(column_count)
			else:
				line_to_save.resize(column_count)
				line_to_save[0] = translation_key

			line_to_save[default_locale_column] = line.text
			if character_column > -1:
				line_to_save[character_column] = "(response)" if line.type == DMConstants.TYPE_RESPONSE else line.character
			if notes_column > -1:
				line_to_save[notes_column] = line.get("notes", "")

			lines_to_save.append(line_to_save)

	# Write the combined CSV. Any keys left in existing_csv are no longer used by any dialogue and are intentionally dropped.
	file = FileAccess.open(to_path, FileAccess.WRITE)
	file.store_csv_line(headings, delimiter)
	for line: Array in lines_to_save:
		file.store_csv_line(line, delimiter)
	file.close()


## Get the delimiter used for an existing CSV
static func get_delimiter_for_csv(path: String, default_delimiter: String = ",") -> String:
	if FileAccess.file_exists(path):
		var import_path: String = "%s.%s" % [path, "import"]
		var import_file: ConfigFile = ConfigFile.new()
		if import_file.load(import_path) == OK:
			match import_file.get_value("params", "delimiter", 0):
				0:
					return ","
				1:
					return ";"
				2:
					return "\t"

	return default_delimiter

## A collection of utility functions for working with dialogue translations.
class_name DMTranslationUtilities extends RefCounted


## Generate translation keys from some text.
static func generate_translation_keys(text: String) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var lines: PackedStringArray = text.split("\n")

	var key_regex = RegEx.new()
	key_regex.compile("\\[ID:(?<key>.*?)\\]")

	var compiled_lines: Dictionary = DMCompiler.compile_string(text, "").lines

	# Make list of known keys
	var known_keys = {}
	for i in range(0, lines.size()):
		var line = lines[i]
		var found = key_regex.search(line)
		if found:
			var translatable_text: String = ""
			var l = line.replace(found.strings[0], "").strip_edges().strip_edges()
			if l.begins_with("- "):
				translatable_text = DMCompiler.extract_translatable_string(l)
			elif ":" in l:
				translatable_text = l.split(":")[1]
			else:
				translatable_text = l
			known_keys[found.strings[found.names.get("key")]] = translatable_text

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

		var key: String = ""
		if known_keys.values().has(translatable_text):
			key = known_keys.find_key(translatable_text)
		else:
			var regex: DMCompilerRegEx = DMCompilerRegEx.new()
			if DMSettings.get_setting(DMSettings.USE_UUID_ONLY_FOR_IDS, false):
				# Generate UUID only
				var uuid = str(randi() % 1000000).sha1_text().substr(0, 12)
				key = uuid.to_upper()
			else:
				# Generate text prefix + hash
				var prefix_length = DMSettings.get_setting(DMSettings.AUTO_GENERATED_ID_PREFIX_LENGTH, 30)
				key = regex.ALPHA_NUMERIC.sub(translatable_text.strip_edges(), "_", true).substr(0, prefix_length)
				if key.begins_with("_"):
					key = key.substr(1)
				if key.ends_with("_"):
					key = key.substr(0, key.length() - 1)

				# Make sure key is unique
				var hashed_key: String = key + "_" + str(randi() % 1000000).sha1_text().substr(0, 6)
				while hashed_key in known_keys and translatable_text != known_keys.get(hashed_key):
					hashed_key = key + "_" + str(randi() % 1000000).sha1_text().substr(0, 6)
				key = hashed_key.to_upper()

		line = line.replace("\\n", "!NEWLINE!")
		translatable_text = translatable_text.replace("\n", "!NEWLINE!")
		lines[i] = line.replace(translatable_text, translatable_text + " [ID:%s]" % [key]).replace("!NEWLINE!", "\\n")

		known_keys[key] = translatable_text

	return "\n".join(lines)


## Export dialogue and responses to CSV.
static func export_translations_to_csv(to_path: String, text: String, dialogue_path: String) -> void:
	var default_locale: String = DMSettings.get_setting(DMSettings.DEFAULT_CSV_LOCALE, "en")

	var file: FileAccess

	# If the file exists, open it first and work out which keys are already in it
	var existing_csv: Dictionary = {}
	var delimiter: String = get_delimiter_for_csv(to_path)
	var column_count: int = 2
	var default_locale_column: int = 1
	var character_column: int = -1
	var notes_column: int = -1
	if FileAccess.file_exists(to_path):
		file = FileAccess.open(to_path, FileAccess.READ)
		var is_first_line = true
		var line: Array
		while !file.eof_reached():
			line = file.get_csv_line(delimiter)
			if is_first_line:
				is_first_line = false
				column_count = line.size()
				for i in range(1, line.size()):
					if line[i] == default_locale:
						default_locale_column = i
					elif line[i] == "_character":
						character_column = i
					elif line[i] == "_notes":
						notes_column = i

			# Make sure the line isn't empty before adding it
			if line.size() > 0 and line[0].strip_edges() != "":
				existing_csv[line[0]] = line

		# The character column wasn't found in the existing file but the setting is turned on
		if character_column == -1 and DMSettings.get_setting(DMSettings.INCLUDE_CHARACTER_IN_TRANSLATION_EXPORTS, false):
			character_column = column_count
			column_count += 1
			existing_csv["keys"].append("_character")

		# The notes column wasn't found in the existing file but the setting is turned on
		if notes_column == -1 and DMSettings.get_setting(DMSettings.INCLUDE_NOTES_IN_TRANSLATION_EXPORTS, false):
			notes_column = column_count
			column_count += 1
			existing_csv["keys"].append("_notes")

	# Start a new file
	file = FileAccess.open(to_path, FileAccess.WRITE)

	if not FileAccess.file_exists(to_path):
		var headings: PackedStringArray = ["keys", default_locale] + DMSettings.get_setting(DMSettings.EXTRA_CSV_LOCALES, [])
		if DMSettings.get_setting(DMSettings.INCLUDE_CHARACTER_IN_TRANSLATION_EXPORTS, false):
			character_column = headings.size()
			headings.append("_character")
		if DMSettings.get_setting(DMSettings.INCLUDE_NOTES_IN_TRANSLATION_EXPORTS, false):
			notes_column = headings.size()
			headings.append("_notes")

		file.store_csv_line(headings, delimiter)
		column_count = headings.size()

	# Write our translations to file
	var known_keys: PackedStringArray = []

	var dialogue = DMCompiler.compile_string(text, dialogue_path).lines

	# Make a list of stuff that needs to go into the file
	var lines_to_save = []
	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)

		if not line.type in [DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RESPONSE]: continue

		var translation_key: String = line.get(&"translation_key", line.text)

		if translation_key in known_keys: continue

		known_keys.append(translation_key)

		var line_to_save: PackedStringArray = []
		if existing_csv.has(translation_key):
			line_to_save = existing_csv.get(translation_key)
			line_to_save.resize(column_count)
			existing_csv.erase(translation_key)
		else:
			line_to_save.resize(column_count)
			line_to_save[0] = translation_key

		line_to_save[default_locale_column] = line.text
		if character_column > -1:
			line_to_save[character_column] = "(response)" if line.type == DMConstants.TYPE_RESPONSE else line.character
		if notes_column > -1:
			line_to_save[notes_column] = line.notes

		lines_to_save.append(line_to_save)

	# Store lines in the file, starting with anything that already exists that hasn't been touched
	for line in existing_csv.values():
		file.store_csv_line(line, delimiter)
	for line in lines_to_save:
		file.store_csv_line(line, delimiter)

	file.close()


## Get the delimier used for an existing CSV
static func get_delimiter_for_csv(path: String) -> String:
	if FileAccess.file_exists(path):
		var import_path: String = "%s.%s" % [path, "import"]
		var import_file: ConfigFile = ConfigFile.new()
		if import_file.load(import_path) == OK:
			match import_file.get_value("params", "delimier", 0):
				0:
					return ","
				1:
					return ";"
				2:
					return "\t"

	match DMSettings.get_setting(DMSettings.DEFAULT_CSV_DELIMITER, "Comma"):
		"Comma":
			return ","
		"Semicolon":
			return ";"
		"Tab":
			return "\t"

	return ","


## Save any character names in a file to CSV.
static func export_character_names_to_csv(to_path: String, text: String, dialogue_path: String) -> void:
	var file: FileAccess

	# If the file exists, open it first and work out which keys are already in it
	var existing_csv = {}
	var delimiter: String = get_delimiter_for_csv(to_path)
	var commas = []
	if FileAccess.file_exists(to_path):
		file = FileAccess.open(to_path, FileAccess.READ)
		var is_first_line = true
		var line: Array
		while !file.eof_reached():
			line = file.get_csv_line(delimiter)
			if is_first_line:
				is_first_line = false
				for i in range(2, line.size()):
					commas.append("")
			# Make sure the line isn't empty before adding it
			if line.size() > 0 and line[0].strip_edges() != "":
				existing_csv[line[0]] = line

	# Start a new file
	file = FileAccess.open(to_path, FileAccess.WRITE)

	if not file.file_exists(to_path):
		file.store_csv_line(["keys", DMSettings.get_setting(DMSettings.DEFAULT_CSV_LOCALE, "en")], delimiter)

	# Write our translations to file
	var known_keys: PackedStringArray = []

	var character_names: PackedStringArray = DMCompiler.compile_string(text, dialogue_path).character_names

	# Make a list of stuff that needs to go into the file
	var lines_to_save = []
	for character_name in character_names:
		if character_name in known_keys: continue

		known_keys.append(character_name)

		if existing_csv.has(character_name):
			var existing_line = existing_csv.get(character_name)
			existing_line[1] = character_name
			lines_to_save.append(existing_line)
			existing_csv.erase(character_name)
		else:
			lines_to_save.append(PackedStringArray([character_name, character_name] + commas))

	# Store lines in the file, starting with anything that already exists that hasn't been touched
	for line in existing_csv.values():
		file.store_csv_line(line, delimiter)
	for line in lines_to_save:
		file.store_csv_line(line, delimiter)

	file.close()


## Replace translatable lines in some text using an existing CSV.
static func import_translations_from_csv(from_path: String, text: String) -> String:
	if not FileAccess.file_exists(from_path): return text

	# Open the CSV file and build a dictionary of the known keys
	var delimiter: String = get_delimiter_for_csv(from_path)
	var keys: Dictionary = {}
	var file: FileAccess = FileAccess.open(from_path, FileAccess.READ)
	var csv_line: Array
	while !file.eof_reached():
		csv_line = file.get_csv_line(delimiter)
		if csv_line.size() > 1:
			keys[csv_line[0]] = csv_line[1]

	# Now look over each line in the dialogue and replace the content for matched keys
	var lines: PackedStringArray = text.split("\n")
	var start_index: int = 0
	var end_index: int = 0
	for i in range(0, lines.size()):
		var line: String = lines[i]
		var translation_key: String = DMCompiler.get_static_line_id(line)
		if keys.has(translation_key):
			if DMCompiler.get_line_type(line) == DMConstants.TYPE_DIALOGUE:
				start_index = 0
				# See if we need to skip over a character name
				line = line.replace("\\:", "!ESCAPED_COLON!")
				if ": " in line:
					start_index = line.find(": ") + 2
				lines[i] = (line.substr(0, start_index) + keys.get(translation_key) + " [ID:" + translation_key + "]").replace("!ESCAPED_COLON!", ":")

			elif DMCompiler.get_line_type(line) == DMConstants.TYPE_RESPONSE:
				start_index = line.find("- ") + 2
				# See if we need to skip over a character name
				line = line.replace("\\:", "!ESCAPED_COLON!")
				if ": " in line:
					start_index = line.find(": ") + 2
				end_index = line.length()
				if " =>" in line:
					end_index = line.find(" =>")
				if " [if " in line:
					end_index = line.find(" [if ")
				lines[i] = (line.substr(0, start_index) + keys.get(translation_key) + " [ID:" + translation_key + "]" + line.substr(end_index)).replace("!ESCAPED_COLON!", ":")

	return "\n".join(lines)

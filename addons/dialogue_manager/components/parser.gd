@tool

class_name DialogueManagerParser extends Object


const DialogueConstants = preload("../constants.gd")
const DialogueSettings = preload("../settings.gd")
const ResolvedLineData = preload("./resolved_line_data.gd")
const ResolvedTagData = preload("./resolved_tag_data.gd")
const DialogueManagerParseResult = preload("./parse_result.gd")


var IMPORT_REGEX: RegEx = RegEx.create_from_string("import \"(?<path>[^\"]+)\" as (?<prefix>[^\\!\\@\\#\\$\\%\\^\\&\\*\\(\\)\\-\\=\\+\\{\\}\\[\\]\\;\\:\\\"\\'\\,\\.\\<\\>\\?\\/\\s]+)")
var USING_REGEX: RegEx = RegEx.create_from_string("using (?<state>.*)")
var VALID_TITLE_REGEX: RegEx = RegEx.create_from_string("^[^\\!\\@\\#\\$\\%\\^\\&\\*\\(\\)\\-\\=\\+\\{\\}\\[\\]\\;\\:\\\"\\'\\,\\.\\<\\>\\?\\/\\s]+$")
var BEGINS_WITH_NUMBER_REGEX: RegEx = RegEx.create_from_string("^\\d")
var TRANSLATION_REGEX: RegEx = RegEx.create_from_string("\\[ID:(?<tr>.*?)\\]")
var TAGS_REGEX: RegEx = RegEx.create_from_string("\\[#(?<tags>.*?)\\]")
var MUTATION_REGEX: RegEx = RegEx.create_from_string("(?<keyword>do|do!|set) (?<mutation>.*)")
var CONDITION_REGEX: RegEx = RegEx.create_from_string("(if|elif|while|else if) (?<condition>.*)")
var WRAPPED_CONDITION_REGEX: RegEx = RegEx.create_from_string("\\[if (?<condition>.*)\\]")
var REPLACEMENTS_REGEX: RegEx = RegEx.create_from_string("{{(.*?)}}")
var GOTO_REGEX: RegEx = RegEx.create_from_string("=><? (?<jump_to_title>.*)")
var INDENT_REGEX: RegEx = RegEx.create_from_string("^\\t+")
var INLINE_RANDOM_REGEX: RegEx = RegEx.create_from_string("\\[\\[(?<options>.*?)\\]\\]")
var INLINE_CONDITIONALS_REGEX: RegEx = RegEx.create_from_string("\\[if (?<condition>.+?)\\](?<body>.*?)\\[\\/if\\]")

var TOKEN_DEFINITIONS: Dictionary = {
	DialogueConstants.TOKEN_FUNCTION: RegEx.create_from_string("^[a-zA-Z_][a-zA-Z_0-9]*\\("),
	DialogueConstants.TOKEN_DICTIONARY_REFERENCE: RegEx.create_from_string("^[a-zA-Z_][a-zA-Z_0-9]*\\["),
	DialogueConstants.TOKEN_PARENS_OPEN: RegEx.create_from_string("^\\("),
	DialogueConstants.TOKEN_PARENS_CLOSE: RegEx.create_from_string("^\\)"),
	DialogueConstants.TOKEN_BRACKET_OPEN: RegEx.create_from_string("^\\["),
	DialogueConstants.TOKEN_BRACKET_CLOSE: RegEx.create_from_string("^\\]"),
	DialogueConstants.TOKEN_BRACE_OPEN: RegEx.create_from_string("^\\{"),
	DialogueConstants.TOKEN_BRACE_CLOSE: RegEx.create_from_string("^\\}"),
	DialogueConstants.TOKEN_COLON: RegEx.create_from_string("^:"),
	DialogueConstants.TOKEN_COMPARISON: RegEx.create_from_string("^(==|<=|>=|<|>|!=|in )"),
	DialogueConstants.TOKEN_ASSIGNMENT: RegEx.create_from_string("^(\\+=|\\-=|\\*=|/=|=)"),
	DialogueConstants.TOKEN_NUMBER: RegEx.create_from_string("^\\-?\\d+(\\.\\d+)?"),
	DialogueConstants.TOKEN_OPERATOR: RegEx.create_from_string("^(\\+|\\-|\\*|/|%)"),
	DialogueConstants.TOKEN_COMMA: RegEx.create_from_string("^,"),
	DialogueConstants.TOKEN_DOT: RegEx.create_from_string("^\\."),
	DialogueConstants.TOKEN_STRING: RegEx.create_from_string("^(\".*?\"|\'.*?\')"),
	DialogueConstants.TOKEN_NOT: RegEx.create_from_string("^(not( |$)|!)"),
	DialogueConstants.TOKEN_AND_OR: RegEx.create_from_string("^(and|or|&&|\\|\\|)( |$)"),
	DialogueConstants.TOKEN_VARIABLE: RegEx.create_from_string("^[a-zA-Z_][a-zA-Z_0-9]*"),
	DialogueConstants.TOKEN_COMMENT: RegEx.create_from_string("^#.*"),
	DialogueConstants.TOKEN_CONDITION: RegEx.create_from_string("^(if|elif|else)"),
	DialogueConstants.TOKEN_BOOL: RegEx.create_from_string("^(true|false)")
}

var WEIGHTED_RANDOM_SIBLINGS_REGEX: RegEx = RegEx.create_from_string("^\\%(?<weight>[\\d.]+)? ")

var raw_lines: PackedStringArray = []
var parent_stack: Array[String] = []

var parsed_lines: Dictionary = {}
var imported_paths: PackedStringArray = []
var using_states: PackedStringArray = []
var titles: Dictionary = {}
var character_names: PackedStringArray = []
var first_title: String = ""
var errors: Array[Dictionary] = []
var raw_text: String = ""

var _imported_line_map: Dictionary = {}
var _imported_line_count: int = 0

var while_loopbacks: Array[String] = []


## Parse some raw dialogue text. Returns a dictionary containing parse results
static func parse_string(string: String, path: String) -> DialogueManagerParseResult:
	var parser: DialogueManagerParser = DialogueManagerParser.new()
	var error: Error = parser.parse(string, path)
	var data: DialogueManagerParseResult = parser.get_data()
	parser.free()

	if error == OK:
		return data
	else:
		return null


## Extract bbcode and other markers from a string
static func extract_markers_from_string(string: String) -> ResolvedLineData:
	var parser: DialogueManagerParser = DialogueManagerParser.new()
	var markers: ResolvedLineData = parser.extract_markers(string)
	parser.free()

	return markers


## Parse some raw dialogue text. Returns a dictionary containing parse results
func parse(text: String, path: String) -> Error:
	prepare(text, path)
	raw_text = text

	# Parse all of the content
	var known_translations = {}

	# Get list of known autoloads
	var autoload_names: PackedStringArray = get_autoload_names()

	# Keep track of the last doc comment
	var doc_comments: Array[String] = []

	# Then parse all lines
	for id in range(0, raw_lines.size()):
		var raw_line: String = raw_lines[id]

		var line: Dictionary = {
			id = str(id),
			next_id = DialogueConstants.ID_NULL
		}

		# Work out if we are inside a conditional or option or if we just
		# indented back out of one
		var indent_size: int = get_indent(raw_line)
		if indent_size < parent_stack.size() and not is_line_empty(raw_line):
			for _tab in range(0, parent_stack.size() - indent_size):
				parent_stack.pop_back()

		# If we are indented then this line should know about its parent
		if parent_stack.size() > 0:
			line["parent_id"] = parent_stack.back()

		# Trim any indentation (now that we've calculated it) so we can check
		# the begining of each line for its type
		raw_line = raw_line.strip_edges(true, false)

		# Grab translations
		var translation_key: String = extract_translation(raw_line)
		if translation_key != "":
			line["translation_key"] = translation_key
			raw_line = raw_line.replace("[ID:%s]" % translation_key, "")

		# Check for each kind of line

		# Start shortcuts
		if raw_line.begins_with("using "):
			var using_match: RegExMatch = USING_REGEX.search(raw_line)
			if "state" in using_match.names:
				var using_state: String = using_match.strings[using_match.names.state].strip_edges()
				if not using_state in autoload_names:
					add_error(id, 0, DialogueConstants.ERR_UNKNOWN_USING)
				elif not using_state in using_states:
					using_states.append(using_state)
			continue

		# Response
		elif is_response_line(raw_line):
			# Add any doc notes
			line["notes"] = "\n".join(doc_comments)
			doc_comments = []

			parent_stack.append(str(id))
			line["type"] = DialogueConstants.TYPE_RESPONSE

			# Extract any #tags
			var tag_data: ResolvedTagData = extract_tags(raw_line)
			line["tags"] = tag_data.tags
			raw_line = tag_data.line_without_tags

			if " [if " in raw_line:
				line["condition"] = extract_condition(raw_line, true, indent_size)
			if " =>" in raw_line:
				line["next_id"] = extract_goto(raw_line)
			if " =><" in raw_line:
				# Because of when the return point needs to be known at runtime we need to split
				# this line into two (otherwise the return point would be dependent on the balloon)
				var goto_line: Dictionary = {
					type = DialogueConstants.TYPE_GOTO,
					next_id = extract_goto(raw_line),
					next_id_after = find_next_line_after_responses(id),
					is_snippet = true
				}
				parsed_lines[str(id) + ".1"] = goto_line
				line["next_id"] = str(id) + ".1"

				# Make sure the added goto line can actually go to somewhere
				if goto_line.next_id in [DialogueConstants.ID_ERROR, DialogueConstants.ID_ERROR_INVALID_TITLE, DialogueConstants.ID_ERROR_TITLE_HAS_NO_BODY]:
					line["next_id"] = goto_line.next_id

			line["character"] = ""
			line["character_replacements"] = [] as Array[Dictionary]
			line["text"] = extract_response_prompt(raw_line)

			var previous_response_id = find_previous_response_id(id)
			if parsed_lines.has(previous_response_id):
				var previous_response = parsed_lines[previous_response_id]
				# Add this response to the list on the first response so that it is the
				# authority on what is in the list of responses
				previous_response["responses"] = previous_response["responses"] + PackedStringArray([str(id)])
			else:
				# No previous response so this is the first in the list
				line["responses"] = PackedStringArray([str(id)])

			line["next_id_after"] = find_next_line_after_responses(id)

			# If this response has no body then the next id is the next id after
			if not line.has("next_id") or line.next_id == DialogueConstants.ID_NULL:
				var next_nonempty_line_id = get_next_nonempty_line_id(id)
				if next_nonempty_line_id != DialogueConstants.ID_NULL:
					if get_indent(raw_lines[next_nonempty_line_id.to_int()]) <= indent_size:
						line["next_id"] = line.next_id_after
					else:
						line["next_id"] = next_nonempty_line_id

			line["text_replacements"] = extract_dialogue_replacements(line.get("text"), indent_size + 2)
			for replacement in line.text_replacements:
				if replacement.has("error"):
					add_error(id, replacement.index, replacement.error)

			# If this response has a character name in it then it will automatically be
			# injected as a line of dialogue if the player selects it
			var response_text: String = line.text.replace("\\:", "!ESCAPED_COLON!")
			if ": " in response_text:
				if DialogueSettings.get_setting("create_lines_for_responses_with_characters", true):
					var first_child: Dictionary = {
						type = DialogueConstants.TYPE_DIALOGUE,
						next_id = line.next_id,
						next_id_after = line.next_id_after,
						text_replacements = line.text_replacements,
						tags = line.tags,
						translation_key = line.get("translation_key")
					}
					parse_response_character_and_text(id, response_text, first_child, indent_size, parsed_lines)
					line["character"] = first_child.character
					line["character_replacements"] = first_child.character_replacements
					line["text"] = first_child.text
					line["text_replacements"] = extract_dialogue_replacements(line.text, indent_size + 2)
					line["translation_key"] = first_child.translation_key
					parsed_lines[str(id) + ".2"] = first_child
					line["next_id"] = str(id) + ".2"
				else:
					parse_response_character_and_text(id, response_text, line, indent_size, parsed_lines)
			else:
				line["text"] = response_text.replace("!ESCAPED_COLON!", ":")

		# Title
		elif is_title_line(raw_line):
			line["type"] = DialogueConstants.TYPE_TITLE
			if not raw_lines[id].begins_with("~"):
				add_error(id, indent_size + 2, DialogueConstants.ERR_NESTED_TITLE)
			else:
				line["text"] = extract_title(raw_line)
				# Titles can't have numbers as the first letter (unless they are external titles which get replaced with hashes)
				if id >= _imported_line_count and BEGINS_WITH_NUMBER_REGEX.search(line.text):
					add_error(id, 2, DialogueConstants.ERR_TITLE_BEGINS_WITH_NUMBER)
				# Only import titles are allowed to have "/" in them
				var valid_title = VALID_TITLE_REGEX.search(raw_line.replace("/", "").substr(2).strip_edges())
				if not valid_title:
					add_error(id, 2, DialogueConstants.ERR_TITLE_INVALID_CHARACTERS)

		# Condition
		elif is_condition_line(raw_line, false):
			parent_stack.append(str(id))
			line["type"] = DialogueConstants.TYPE_CONDITION
			line["condition"] = extract_condition(raw_line, false, indent_size)
			line["next_id_after"] = find_next_line_after_conditions(id)
			var next_sibling_id = find_next_condition_sibling(id)
			line["next_conditional_id"] = next_sibling_id if is_valid_id(next_sibling_id) else line.next_id_after

		elif is_condition_line(raw_line, true):
			parent_stack.append(str(id))
			line["type"] = DialogueConstants.TYPE_CONDITION
			line["next_id_after"] = find_next_line_after_conditions(id)
			line["next_conditional_id"] = line["next_id_after"]

		elif is_while_condition_line(raw_line):
			parent_stack.append(str(id))
			line["type"] = DialogueConstants.TYPE_CONDITION
			line["condition"] = extract_condition(raw_line, false, indent_size)
			line["next_id_after"] = find_next_line_after_conditions(id)
			while_loopbacks.append(find_last_line_within_conditions(id))
			line["next_conditional_id"] = line["next_id_after"]

		# Mutation
		elif is_mutation_line(raw_line):
			line["type"] = DialogueConstants.TYPE_MUTATION
			line["mutation"] = extract_mutation(raw_line)

		# Goto
		elif is_goto_line(raw_line):
			line["type"] = DialogueConstants.TYPE_GOTO

			if raw_line.begins_with("%"):
				apply_weighted_random(id, raw_line, indent_size, line)

			line["next_id"] = extract_goto(raw_line)
			if is_goto_snippet_line(raw_line):
				line["is_snippet"] = true
				line["next_id_after"] = get_line_after_line(id, indent_size, line)
			else:
				line["is_snippet"] = false

		# Nested dialogue
		elif is_nested_dialogue_line(raw_line, parsed_lines, raw_lines, indent_size):
			var parent_line: Dictionary = parsed_lines.values().back()
			var parent_indent_size: int = get_indent(raw_lines[parent_line.id.to_int()])
			var should_update_translation_key: bool = parent_line.translation_key == parent_line.text
			var suffix: String = raw_line.strip_edges(true, false)
			if suffix == "":
				suffix = " "
			parent_line["text"] += "\n" + suffix
			parent_line["text_replacements"] = extract_dialogue_replacements(parent_line.text, parent_line.character.length() + 2 + parent_indent_size)
			for replacement in parent_line.text_replacements:
				if replacement.has("error"):
					add_error(id, replacement.index, replacement.error)

			if should_update_translation_key:
				parent_line["translation_key"] = parent_line.text

			parent_line["next_id"] = get_line_after_line(id, parent_indent_size, parent_line)

			# Ignore this line when checking for indent errors
			remove_error(parent_line.id.to_int(), DialogueConstants.ERR_INVALID_INDENTATION)

			var next_line = raw_lines[parent_line.next_id.to_int()]
			if not is_dialogue_line(next_line) and get_indent(next_line) >= indent_size:
				add_error(parent_line.next_id.to_int(), indent_size, DialogueConstants.ERR_INVALID_INDENTATION)

			continue

		elif raw_line.strip_edges().begins_with("##"):
			doc_comments.append(raw_line.replace("##", "").strip_edges())
			continue

		elif is_line_empty(raw_line) or is_import_line(raw_line):
			continue

		# Regular dialogue
		else:
			# Remove escape character
			if raw_line.begins_with("\\using"): raw_line = raw_line.substr(1)
			if raw_line.begins_with("\\if"): raw_line = raw_line.substr(1)
			if raw_line.begins_with("\\elif"): raw_line = raw_line.substr(1)
			if raw_line.begins_with("\\else"): raw_line = raw_line.substr(1)
			if raw_line.begins_with("\\while"): raw_line = raw_line.substr(1)
			if raw_line.begins_with("\\-"): raw_line = raw_line.substr(1)
			if raw_line.begins_with("\\~"): raw_line = raw_line.substr(1)
			if raw_line.begins_with("\\=>"): raw_line = raw_line.substr(1)

			# Add any doc notes
			line["notes"] = "\n".join(doc_comments)
			doc_comments = []

			# Work out any weighted random siblings
			if raw_line.begins_with("%"):
				apply_weighted_random(id, raw_line, indent_size, line)
				raw_line = WEIGHTED_RANDOM_SIBLINGS_REGEX.sub(raw_line, "")

			line["type"] = DialogueConstants.TYPE_DIALOGUE

			# Extract any tags before we process the line
			var tag_data: ResolvedTagData = extract_tags(raw_line)
			line["tags"] = tag_data.tags
			raw_line = tag_data.line_without_tags

			var l = raw_line.replace("\\:", "!ESCAPED_COLON!")
			if ": " in l:
				var bits = Array(l.strip_edges().split(": "))
				line["character"] = bits.pop_front().strip_edges()
				if not line["character"] in character_names:
					character_names.append(line["character"])
				# You can use variables in the character's name
				line["character_replacements"] = extract_dialogue_replacements(line.character, indent_size)
				for replacement in line.character_replacements:
					if replacement.has("error"):
						add_error(id, replacement.index, replacement.error)
				line["text"] = ": ".join(bits).replace("!ESCAPED_COLON!", ":")
			else:
				line["character"] = ""
				line["character_replacements"] = [] as Array[Dictionary]
				line["text"] = l.replace("!ESCAPED_COLON!", ":")

			line["text_replacements"] = extract_dialogue_replacements(line.text, line.character.length() + 2 + indent_size)
			for replacement in line.text_replacements:
				if replacement.has("error"):
					add_error(id, replacement.index, replacement.error)

			# Unescape any newlines
			line["text"] = line.text.replace("\\n", "\n").strip_edges()

		# Work out where to go after this line
		if line.next_id == DialogueConstants.ID_NULL:
			line["next_id"] = get_line_after_line(id, indent_size, line)

		# Check for duplicate translation keys
		if line.type in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]:
			if line.has("translation_key"):
				if known_translations.has(line.translation_key) and known_translations.get(line.translation_key) != line.text:
					add_error(id, indent_size, DialogueConstants.ERR_DUPLICATE_ID)
				else:
					known_translations[line.translation_key] = line.text
			else:
				# Default translations key
				if DialogueSettings.get_setting("missing_translations_are_errors", false):
					add_error(id, indent_size, DialogueConstants.ERR_MISSING_ID)
				else:
					line["translation_key"] = line.text

		## Error checking

		# Can't find goto
		var jump_index: int = raw_line.find("=>")
		match line.next_id:
			DialogueConstants.ID_ERROR:
				add_error(id, jump_index, DialogueConstants.ERR_UNKNOWN_TITLE)
			DialogueConstants.ID_ERROR_INVALID_TITLE:
				add_error(id, jump_index, DialogueConstants.ERR_INVALID_TITLE_REFERENCE)
			DialogueConstants.ID_ERROR_TITLE_HAS_NO_BODY:
				add_error(id, jump_index, DialogueConstants.ERR_TITLE_REFERENCE_HAS_NO_CONTENT)

		# Line after condition isn't indented once to the right
		if line.type == DialogueConstants.TYPE_CONDITION:
			if is_valid_id(line.next_id):
				var next_line: String = raw_lines[line.next_id.to_int()]
				var next_indent: int = get_indent(next_line)
				if next_indent != indent_size + 1:
					add_error(line.next_id.to_int(), next_indent, DialogueConstants.ERR_INVALID_INDENTATION)
			else:
				add_error(id, indent_size, DialogueConstants.ERR_INVALID_CONDITION_INDENTATION)

		# Line after normal line is indented to the right
		elif line.type in [
				DialogueConstants.TYPE_TITLE,
				DialogueConstants.TYPE_DIALOGUE,
				DialogueConstants.TYPE_MUTATION,
				DialogueConstants.TYPE_GOTO
			] and is_valid_id(line.next_id):
			var next_line = raw_lines[line.next_id.to_int()]
			if next_line != null and get_indent(next_line) > indent_size:
				add_error(id, indent_size, DialogueConstants.ERR_INVALID_INDENTATION)

		# Parsing condition failed
		if line.has("condition") and line.condition.has("error"):
			add_error(id, line.condition.index, line.condition.error)

		# Parsing mutation failed
		elif line.has("mutation") and line.mutation.has("error"):
			add_error(id, line.mutation.index, line.mutation.error)

		# Line failed to parse at all
		if line.get("type") == DialogueConstants.TYPE_UNKNOWN:
			add_error(id, 0, DialogueConstants.ERR_UNKNOWN_LINE_SYNTAX)

		# If there are no titles then use the first actual line
		if first_title == "" and  not is_import_line(raw_line):
			first_title = str(id)

		# If this line is the last line of a while loop, edit the id of its next line
		if str(id) in while_loopbacks:
			if is_goto_snippet_line(raw_line):
				line["next_id_after"] = line["parent_id"]
			elif is_condition_line(raw_line, true) or is_while_condition_line(raw_line):
				line["next_conditional_id"] = line["parent_id"]
				line["next_id_after"] = line["parent_id"]
			elif is_goto_line(raw_line) or is_title_line(raw_line):
				pass
			else:
				line["next_id"] = line["parent_id"]

		# Done!
		parsed_lines[str(id)] = line

	# Assume the last line ends the dialogue
	var last_line: Dictionary = parsed_lines.values()[parsed_lines.values().size() - 1]
	if last_line.next_id == "":
		last_line.next_id = DialogueConstants.ID_END

	if errors.size() > 0:
		return ERR_PARSE_ERROR

	return OK


func get_data() -> DialogueManagerParseResult:
	var data: DialogueManagerParseResult = DialogueManagerParseResult.new()
	data.imported_paths = imported_paths
	data.using_states = using_states
	data.titles = titles
	data.character_names = character_names
	data.first_title = first_title
	data.lines = parsed_lines
	data.errors = errors
	data.raw_text = raw_text
	return data


## Get the last parse errors
func get_errors() -> Array[Dictionary]:
	return errors


## Prepare the parser by collecting all lines and titles
func prepare(text: String, path: String, include_imported_titles_hashes: bool = true) -> void:
	using_states = []
	errors = []
	imported_paths = []
	_imported_line_map = {}
	while_loopbacks = []
	titles = {}
	character_names = []
	first_title = ""
	raw_lines = text.split("\n")

	# Work out imports
	var known_imports: Dictionary = {}

	# Include the base file path so that we can get around circular dependencies
	known_imports[path.hash()] = "."

	var imported_titles: Dictionary = {}
	for id in range(0, raw_lines.size()):
		var line = raw_lines[id]
		if is_import_line(line):
			var import_data = extract_import_path_and_name(line)
			var import_hash: int = import_data.path.hash()
			if import_data.size() > 0:
				# Keep track of titles so we can add imported ones later
				if str(import_hash) in imported_titles.keys():
					add_error(id, 0, DialogueConstants.ERR_FILE_ALREADY_IMPORTED)
				if import_data.prefix in imported_titles.values():
					add_error(id, 0, DialogueConstants.ERR_DUPLICATE_IMPORT_NAME)
				imported_titles[str(import_hash)] = import_data.prefix

				# Import the file content
				if not known_imports.has(import_hash):
					var error: Error = import_content(import_data.path, import_data.prefix, _imported_line_map, known_imports)
					if error != OK:
						add_error(id, 0, error)

				# Make a map so we can refer compiled lines to where they were imported from
				if not _imported_line_map.has(import_hash):
					_imported_line_map[import_hash] = {
						hash = import_hash,
						imported_on_line_number = id,
						from_line = 0,
						to_line = 0
					}

	var imported_content: String =  ""
	var cummulative_line_number: int = 0
	for item in _imported_line_map.values():
		item["from_line"] = cummulative_line_number
		if known_imports.has(item.hash):
			cummulative_line_number += known_imports[item.hash].split("\n").size()
		item["to_line"] = cummulative_line_number
		if known_imports.has(item.hash):
			imported_content += known_imports[item.hash] + "\n"

	_imported_line_count = cummulative_line_number + 1

	# Join it with the actual content
	raw_lines = (imported_content + "\n" + text).split("\n")

	# Find all titles first
	for id in range(0, raw_lines.size()):
		if raw_lines[id].begins_with("~ "):
			var title: String = extract_title(raw_lines[id])
			if title == "":
				add_error(id, 2, DialogueConstants.ERR_EMPTY_TITLE)
			elif titles.has(title):
				add_error(id, 2, DialogueConstants.ERR_DUPLICATE_TITLE)
			else:
				var next_nonempty_line_id: String = get_next_nonempty_line_id(id)
				if next_nonempty_line_id != DialogueConstants.ID_NULL:
					titles[title] = next_nonempty_line_id
					if "/" in title:
						if include_imported_titles_hashes == false:
							titles.erase(title)
						var bits: PackedStringArray = title.split("/")
						if imported_titles.has(bits[0]):
							title = imported_titles[bits[0]] + "/" + bits[1]
							titles[title] = next_nonempty_line_id
					elif first_title == "":
						first_title = next_nonempty_line_id
				else:
					titles[title] = DialogueConstants.ID_ERROR_TITLE_HAS_NO_BODY


func add_error(line_number: int, column_number: int, error: int) -> void:
	# See if the error was in an imported file
	for item in _imported_line_map.values():
		if line_number < item.to_line:
			errors.append({
				line_number = item.imported_on_line_number,
				column_number = 0,
				error = DialogueConstants.ERR_ERRORS_IN_IMPORTED_FILE,
				external_error = error,
				external_line_number = line_number
			})
			return

	# Otherwise, it's in this file
	errors.append({
		line_number = line_number - _imported_line_count,
		column_number = column_number,
		error = error
	})


func remove_error(line_number: int, error: int) -> void:
	for i in range(errors.size() - 1, -1, -1):
		var err = errors[i]
		var is_native_error = err.line_number == line_number - _imported_line_count and err.error == error
		var is_external_error = err.get("external_line_number") == line_number and err.get("external_error") == error
		if is_native_error or is_external_error:
			errors.remove_at(i)
			return


func is_import_line(line: String) -> bool:
	return line.begins_with("import ") and " as " in line


func is_title_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("~ ")


func is_condition_line(line: String, include_else: bool = true) -> bool:
	line = line.strip_edges(true, false)
	if line.begins_with("if ") or line.begins_with("elif ") or line.begins_with("else if"): return true
	if include_else and line.begins_with("else"): return true
	return false

func is_while_condition_line(line: String) -> bool:
	line = line.strip_edges(true, false)
	if line.begins_with("while "): return true
	return false


func is_mutation_line(line: String) -> bool:
	line = line.strip_edges(true, false)
	return line.begins_with("do ") or line.begins_with("do! ") or line.begins_with("set ")


func is_goto_line(line: String) -> bool:
	line = line.strip_edges(true, false)
	line = WEIGHTED_RANDOM_SIBLINGS_REGEX.sub(line, "")
	return line.begins_with("=> ") or line.begins_with("=>< ")


func is_goto_snippet_line(line: String) -> bool:
	line = WEIGHTED_RANDOM_SIBLINGS_REGEX.sub(line.strip_edges(), "")
	return line.begins_with("=>< ")


func is_nested_dialogue_line(raw_line: String, parsed_lines: Dictionary, raw_lines: PackedStringArray, indent_size: int) -> bool:
	if parsed_lines.values().is_empty(): return false
	if raw_line.strip_edges().begins_with("#"): return false

	var parent_line: Dictionary = parsed_lines.values().back()
	if parent_line.type != DialogueConstants.TYPE_DIALOGUE: return false
	if get_indent(raw_lines[parent_line.id.to_int()]) >= indent_size: return false
	return true


func is_dialogue_line(line: String) -> bool:
	if line == null: return false
	if is_response_line(line): return false
	if is_title_line(line): return false
	if is_condition_line(line, true): return false
	if is_mutation_line(line): return false
	if is_goto_line(line): return false
	return true


func is_response_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("- ")


func is_valid_id(id: String) -> bool:
	return false if id in [DialogueConstants.ID_NULL, DialogueConstants.ID_ERROR, DialogueConstants.ID_END_CONVERSATION] else true


func is_line_empty(line: String) -> bool:
	line = line.strip_edges()

	if line == "": return true
	if line == "endif": return true
	if line.begins_with("#"): return true

	return false


func get_line_after_line(id: int, indent_size: int, line: Dictionary) -> String:
	# Unless the next line is an outdent we can assume it comes next
	var next_nonempty_line_id = get_next_nonempty_line_id(id)
	if next_nonempty_line_id != DialogueConstants.ID_NULL \
		and indent_size <= get_indent(raw_lines[next_nonempty_line_id.to_int()]):
		return next_nonempty_line_id
	# Otherwise, we grab the ID from the parents next ID after children
	elif line.has("parent_id") and parsed_lines.has(line.parent_id):
		return parsed_lines[line.parent_id].next_id_after

	else:
		return DialogueConstants.ID_NULL


func get_indent(line: String) -> int:
	var tabs: RegExMatch = INDENT_REGEX.search(line)
	if tabs:
		return tabs.get_string().length()
	else:
		return 0


func get_next_nonempty_line_id(line_number: int) -> String:
	for i in range(line_number + 1, raw_lines.size()):
		if not is_line_empty(raw_lines[i]):
			return str(i)
	return DialogueConstants.ID_NULL


func find_previous_response_id(line_number: int) -> String:
	var line = raw_lines[line_number]
	var indent_size = get_indent(line)

	# Look back up the list to find the previous response
	var last_found_response_id: String = str(line_number)

	for i in range(line_number - 1, -1, -1):
		line = raw_lines[i]

		if is_line_empty(line): continue

		# If its a response at the same indent level then its a match
		elif get_indent(line) == indent_size:
			if line.strip_edges().begins_with("- "):
				last_found_response_id = str(i)
			else:
				return last_found_response_id

	# Return itself if nothing was found
	return last_found_response_id


func apply_weighted_random(id: int, raw_line: String, indent_size: int, line: Dictionary) -> void:
	var weight: float = 1
	var found = WEIGHTED_RANDOM_SIBLINGS_REGEX.search(raw_line)
	if found and found.names.has("weight"):
		weight = found.strings[found.names.weight].to_float()

	# Look back up the list to find the first weighted random line in this group
	var original_random_line: Dictionary = {}
	for i in range(id, 0, -1):
		# Ignore doc comment lines
		if raw_lines[i].strip_edges().begins_with("##"):
			continue
		# Lines that aren't prefixed with the random token are a dead end
		if not raw_lines[i].strip_edges().begins_with("%") or get_indent(raw_lines[i]) != indent_size:
			break
		# Make sure we group random dialogue and random lines separately
		elif WEIGHTED_RANDOM_SIBLINGS_REGEX.sub(raw_line.strip_edges(), "").begins_with("=") != WEIGHTED_RANDOM_SIBLINGS_REGEX.sub(raw_lines[i].strip_edges(), "").begins_with("="):
			break
		# Otherwise we've found the origin
		elif parsed_lines.has(str(i)) and parsed_lines[str(i)].has("siblings"):
			original_random_line = parsed_lines[str(i)]
			break

	# Attach it to the original random line and work out where to go after the line
	if original_random_line.size() > 0:
		original_random_line["siblings"] += [{ weight = weight, id = str(id) }]
		if original_random_line.type != DialogueConstants.TYPE_GOTO:
			# Update the next line for all siblings (not goto lines, though, they manager their
			# own next ID)
			original_random_line["next_id"] = get_line_after_line(id, indent_size, line)
			for sibling in original_random_line["siblings"]:
				if sibling.id in parsed_lines:
					parsed_lines[sibling.id]["next_id"] = original_random_line["next_id"]
		line["next_id"] = original_random_line.next_id
	# Or set up this line as the original
	else:
		line["siblings"] = [{ weight = weight, id = str(id) }]
		line["next_id"] = get_line_after_line(id, indent_size, line)

	if line.next_id == DialogueConstants.ID_NULL:
		line["next_id"] = DialogueConstants.ID_END


func find_next_condition_sibling(line_number: int) -> String:
	var line = raw_lines[line_number]
	var expected_indent = get_indent(line)

	# Look down the list and find an elif or else at the same indent level
	for i in range(line_number + 1, raw_lines.size()):
		line = raw_lines[i]
		if is_line_empty(line): continue

		var l = line.strip_edges()
		if l.begins_with("~ "):
			return DialogueConstants.ID_END_CONVERSATION

		elif get_indent(line) < expected_indent:
			return DialogueConstants.ID_NULL

		elif get_indent(line) == expected_indent:
			# Found an if, which begins a different block
			if l.begins_with("if"):
				return DialogueConstants.ID_NULL

			# Found what we're looking for
			elif (l.begins_with("elif ") or l.begins_with("else")):
				return str(i)

	return DialogueConstants.ID_NULL


func find_next_line_after_conditions(line_number: int) -> String:
	var line = raw_lines[line_number]
	var expected_indent = get_indent(line)

	# Look down the list for the first non condition line at the same or less indent level
	for i in range(line_number + 1, raw_lines.size()):
		line = raw_lines[i]

		if is_line_empty(line): continue

		var line_indent = get_indent(line)
		line = line.strip_edges()

		if is_title_line(line):
			return get_next_nonempty_line_id(i)

		elif line_indent > expected_indent:
			continue

		elif line_indent == expected_indent:
			if line.begins_with("elif ") or line.begins_with("else"):
				continue
			else:
				return str(i)

		elif line_indent < expected_indent:
			# We have to check the parent of this block
			for p in range(line_number - 1, -1, -1):
				line = raw_lines[p]

				if is_line_empty(line): continue

				line_indent = get_indent(line)
				if line_indent < expected_indent:
					return parsed_lines[str(p)].get("next_id_after", DialogueConstants.ID_NULL)

	return DialogueConstants.ID_END_CONVERSATION

func find_last_line_within_conditions(line_number: int) -> String:
	var line = raw_lines[line_number]
	var expected_indent = get_indent(line)

	var candidate = DialogueConstants.ID_NULL

	# Look down the list for the last line that has an indent level 1 more than this line
	# Ending the search when you find a line the same or less indent level
	for i in range(line_number + 1, raw_lines.size()):
		line = raw_lines[i]

		if is_line_empty(line): continue

		var line_indent = get_indent(line)
		line = line.strip_edges()

		if line_indent > expected_indent + 1:
			continue
		elif line_indent == (expected_indent + 1):
			candidate = i
		else:
			break

	return str(candidate)

func find_next_line_after_responses(line_number: int) -> String:
	var line = raw_lines[line_number]
	var expected_indent = get_indent(line)

	# Find the first line after this one that has a smaller indent that isn't another option
	# If we hit the eof then we give up
	for i in range(line_number + 1, raw_lines.size()):
		line = raw_lines[i]

		if is_line_empty(line): continue

		var indent = get_indent(line)

		line = line.strip_edges()

		# We hit a title so the next line is a new start
		if is_title_line(line):
			return get_next_nonempty_line_id(i)

		# Another option
		elif line.begins_with("- "):
			if indent == expected_indent:
				# ...at the same level so we continue
				continue
			elif indent < expected_indent:
				# ...outdented so check the previous parent
				var previous_parent = parent_stack[parent_stack.size() - 2]
				if parsed_lines.has(str(previous_parent)):
					return parsed_lines[str(previous_parent)].next_id_after
				else:
					return DialogueConstants.ID_NULL

		# We're at the end of a conditional so jump back up to see what's after it
		elif line.begins_with("elif ") or line.begins_with("else"):
			for p in range(line_number - 1, -1, -1):
				line = raw_lines[p]

				if is_line_empty(line): continue

				var line_indent = get_indent(line)
				if line_indent < expected_indent:
					return parsed_lines[str(p)].next_id_after

		# Otherwise check the indent for an outdent
		else:
			line_number = i
			line = raw_lines[line_number]
			if get_indent(line) <= expected_indent:
				return str(line_number)

	# EOF so it's also the end of a block
	return DialogueConstants.ID_END


## Get the names of any autoloads in the project
func get_autoload_names() -> PackedStringArray:
	var autoloads: PackedStringArray = []

	var project = ConfigFile.new()
	project.load("res://project.godot")
	if project.has_section("autoload"):
		return Array(project.get_section_keys("autoload")).filter(func(key): return key != "DialogueManager")

	return autoloads


## Import content from another dialogue file or return an ERR
func import_content(path: String, prefix: String, imported_line_map: Dictionary, known_imports: Dictionary) -> Error:
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content: PackedStringArray = file.get_as_text().split("\n")

		var imported_titles: Dictionary = {}

		for index in range(0, content.size()):
			var line = content[index]
			if is_import_line(line):
				var import = extract_import_path_and_name(line)
				if import.size() > 0:
					if not known_imports.has(import.path.hash()):
						# Add an empty record into the keys just so we don't end up with cyclic dependencies
						known_imports[import.path.hash()] = ""
						if import_content(import.path, import.prefix, imported_line_map, known_imports) != OK:
							return ERR_LINK_FAILED

					if not imported_line_map.has(import.path.hash()):
						# Make a map so we can refer compiled lines to where they were imported from
						imported_line_map[import.path.hash()] = {
							hash = import.path.hash(),
							imported_on_line_number = index,
							from_line = 0,
							to_line = 0
						}

					imported_titles[import.prefix] = import.path.hash()

		var origin_hash: int = -1
		for hash_value in known_imports.keys():
			if known_imports[hash_value] == ".":
				origin_hash = hash_value

		# Replace any titles or jump points with references to the files they point to (event if they point to their own file)
		for i in range(0, content.size()):
			var line = content[i]
			if is_title_line(line):
				var title = extract_title(line)
				if "/" in line:
					var bits = title.split("/")
					content[i] = "~ %s/%s" % [imported_titles[bits[0]], bits[1]]
				else:
					content[i] = "~ %s/%s" % [str(path.hash()), title]

			elif "=>< " in line:
				var jump: String = line.substr(line.find("=>< ") + "=>< ".length()).strip_edges()
				if "/" in jump:
					var bits: PackedStringArray = jump.split("/")
					var title_hash: int = imported_titles[bits[0]]
					if title_hash == origin_hash:
						content[i] = "%s=>< %s" % [line.split("=>< ")[0], bits[1]]
					else:
						content[i] = "%s=>< %s/%s" % [line.split("=>< ")[0], title_hash, bits[1]]

				elif not jump in ["END", "END!"]:
					content[i] = "%s=>< %s/%s" % [line.split("=>< ")[0], str(path.hash()), jump]

			elif "=> " in line:
				var jump: String = line.substr(line.find("=> ") + "=> ".length()).strip_edges()
				if "/" in jump:
					var bits: PackedStringArray = jump.split("/")
					var title_hash: int = imported_titles[bits[0]]
					if title_hash == origin_hash:
						content[i] = "%s=> %s" % [line.split("=> ")[0], bits[1]]
					else:
						content[i] = "%s=> %s/%s" % [line.split("=> ")[0], title_hash, bits[1]]

				elif not jump in ["END", "END!"]:
					content[i] = "%s=> %s/%s" % [line.split("=> ")[0], str(path.hash()), jump]

		imported_paths.append(path)
		known_imports[path.hash()] = "\n".join(content) + "\n=> END\n"
		return OK
	else:
		return ERR_FILE_NOT_FOUND


func extract_import_path_and_name(line: String) -> Dictionary:
	var found: RegExMatch = IMPORT_REGEX.search(line)
	if found:
		return {
			path = found.strings[found.names.path],
			prefix = found.strings[found.names.prefix]
		}
	else:
		return {}


func extract_title(line: String) -> String:
	return line.substr(2).strip_edges()


func extract_translation(line: String) -> String:
	# Find a static translation key, eg. [ID:something]
	var found: RegExMatch = TRANSLATION_REGEX.search(line)
	if found:
		return found.strings[found.names.tr]
	else:
		return ""


func extract_response_prompt(line: String) -> String:
	# Find just the text prompt from a response, ignoring any conditions or gotos
	line = line.substr(2)
	if " [if " in line:
		line = line.substr(0, line.find(" [if "))
	if " =>" in line:
		line = line.substr(0, line.find(" =>"))

	# Without the translation key if there is one
	var translation_key: String = extract_translation(line)
	if translation_key:
		line = line.replace("[ID:%s]" % translation_key, "")

	return line.replace("\\n", "\n").strip_edges()


func parse_response_character_and_text(id: int, text: String, line: Dictionary, indent_size: int, parsed_lines: Dictionary) -> void:
	var bits = Array(text.strip_edges().split(": "))
	line["character"] = bits.pop_front().strip_edges()
	line["character_replacements"] = extract_dialogue_replacements(line.character, line.character.length() + 2 + indent_size)
	for replacement in line.character_replacements:
		if replacement.has("error"):
			add_error(id, replacement.index, replacement.error)

	if not line["character"] in character_names:
		character_names.append(line["character"])

	line["text"] = ": ".join(bits).replace("!ESCAPED_COLON!", ":").strip_edges()

	if line.get("translation_key", null) == null:
		line["translation_key"] = line.text


func extract_mutation(line: String) -> Dictionary:
	var found: RegExMatch = MUTATION_REGEX.search(line)

	if not found:
		return {
			index = 0,
			error = DialogueConstants.ERR_INCOMPLETE_EXPRESSION
		}

	if found.names.has("mutation"):
		var expression: Array = tokenise(found.strings[found.names.mutation], DialogueConstants.TYPE_MUTATION, found.get_start("mutation"))
		if expression.size() == 0:
			return {
				index = found.get_start("mutation"),
				error = DialogueConstants.ERR_INCOMPLETE_EXPRESSION
			}
		elif expression[0].type == DialogueConstants.TYPE_ERROR:
			return {
				index = expression[0].index,
				error = expression[0].value
			}
		else:
			return {
				expression = expression,
				is_blocking = not "!" in found.strings[found.names.keyword]
			}

	else:
		return {
			index = found.get_start(),
			error = DialogueConstants.ERR_INCOMPLETE_EXPRESSION
		}


func extract_condition(raw_line: String, is_wrapped: bool, index: int) -> Dictionary:
	var condition: Dictionary = {}

	var regex: RegEx = WRAPPED_CONDITION_REGEX if is_wrapped else CONDITION_REGEX
	var found: RegExMatch = regex.search(raw_line)

	if found == null:
		return {
			index = 0,
			error = DialogueConstants.ERR_INCOMPLETE_EXPRESSION
		}

	var raw_condition: String = found.strings[found.names.condition]
	var expression: Array = tokenise(raw_condition, DialogueConstants.TYPE_CONDITION, index + found.get_start("condition"))

	if expression.size() == 0:
		return {
			index = index + found.get_start("condition"),
			error = DialogueConstants.ERR_INCOMPLETE_EXPRESSION
		}
	elif expression[0].type == DialogueConstants.TYPE_ERROR:
		return {
			index = expression[0].index,
			error = expression[0].value
		}
	else:
		return {
			expression = expression
		}


func extract_dialogue_replacements(text: String, index: int) -> Array[Dictionary]:
	var founds: Array[RegExMatch] = REPLACEMENTS_REGEX.search_all(text)

	if founds == null or founds.size() == 0:
		return []

	var replacements: Array[Dictionary] = []
	for found in founds:
		var replacement: Dictionary = {}
		var value_in_text: String = found.strings[1]
		var expression: Array = tokenise(value_in_text, DialogueConstants.TYPE_DIALOGUE, index + found.get_start(1))
		if expression.size() == 0:
			replacement = {
				index = index + found.get_start(1),
				error = DialogueConstants.ERR_INCOMPLETE_EXPRESSION
			}
		elif expression[0].type == DialogueConstants.TYPE_ERROR:
			replacement = {
				index = expression[0].index,
				error = expression[0].value
			}
		else:
			replacement = {
				value_in_text = "{{%s}}" % value_in_text,
				expression = expression
			}
		replacements.append(replacement)

	return replacements


func extract_goto(line: String) -> String:
	var found: RegExMatch = GOTO_REGEX.search(line)

	if found == null: return DialogueConstants.ID_ERROR

	var title: String = found.strings[found.names.jump_to_title].strip_edges()

	if " " in title or title == "":
		return DialogueConstants.ID_ERROR_INVALID_TITLE

	# "=> END!" means end the conversation
	if title == "END!":
		return DialogueConstants.ID_END_CONVERSATION
	# "=> END" means end the current title (and go back to the previous one if there is one
	#		   in the stack)
	elif title == "END":
		return DialogueConstants.ID_END

	elif titles.has(title):
		return titles.get(title)
	else:
		return DialogueConstants.ID_ERROR


func extract_tags(line: String) -> ResolvedTagData:
	var resolved_tags: PackedStringArray = []
	var tag_matches: Array[RegExMatch] = TAGS_REGEX.search_all(line)
	for tag_match in tag_matches:
		line = line.replace(tag_match.get_string(), "")
		var tags = tag_match.get_string().replace("[#", "").replace("]", "").replace(", ", ",").split(",")
		for tag in tags:
			tag = tag.replace("#", "")
			if not tag in resolved_tags:
				resolved_tags.append(tag)

	return ResolvedTagData.new({
		tags = resolved_tags,
		line_without_tags = line
	})


func extract_markers(line: String) -> ResolvedLineData:
	var text: String = line
	var pauses: Dictionary = {}
	var speeds: Dictionary = {}
	var mutations: Array[Array] = []
	var bbcodes: Array = []
	var time: String = ""

	# Remove any escaped brackets (ie. "\[")
	var escaped_open_brackets: PackedInt32Array = []
	var escaped_close_brackets: PackedInt32Array = []
	for i in range(0, text.length() - 1):
		if text.substr(i, 2) == "\\[":
			text = text.substr(0, i) + "!" + text.substr(i + 2)
			escaped_open_brackets.append(i)
		elif text.substr(i, 2) == "\\]":
			text = text.substr(0, i) + "!" + text.substr(i + 2)
			escaped_close_brackets.append(i)

	# Extract all of the BB codes so that we know the actual text (we could do this easier with
	# a RichTextLabel but then we'd need to await idle_frame which is annoying)
	var bbcode_positions = find_bbcode_positions_in_string(text)
	var accumulaive_length_offset = 0
	for position in bbcode_positions:
		# Ignore our own markers
		if position.code in ["wait", "speed", "/speed", "do", "do!", "set", "next", "if", "else", "/if"]:
			continue

		bbcodes.append({
			bbcode = position.bbcode,
			start = position.start,
			offset_start = position.start - accumulaive_length_offset
		})
		accumulaive_length_offset += position.bbcode.length()

	for bb in bbcodes:
		text = text.substr(0, bb.offset_start) + text.substr(bb.offset_start + bb.bbcode.length())

	# Now find any dialogue markers
	var next_bbcode_position = find_bbcode_positions_in_string(text, false)
	var limit = 0
	while next_bbcode_position.size() > 0 and limit < 1000:
		limit += 1

		var bbcode = next_bbcode_position[0]

		var index = bbcode.start
		var code = bbcode.code
		var raw_args = bbcode.raw_args
		var args = {}
		if code in ["do", "do!", "set"]:
			args["value"] = extract_mutation("%s %s" % [code, raw_args])
		else:
			# Could be something like:
			# 	"=1.0"
			# 	" rate=20 level=10"
			if raw_args and raw_args[0] == "=":
				raw_args = "value" + raw_args
			for pair in raw_args.strip_edges().split(" "):
				if "=" in pair:
					var bits = pair.split("=")
					args[bits[0]] = bits[1]

		match code:
			"wait":
				if pauses.has(index):
					pauses[index] += args.get("value").to_float()
				else:
					pauses[index] = args.get("value").to_float()
			"speed":
				speeds[index] = args.get("value").to_float()
			"/speed":
				speeds[index] = 1.0
			"do", "do!", "set":
				mutations.append([index, args.get("value")])
			"next":
				time = args.get("value") if args.has("value") else "0"

		# Find any BB codes that are after this index and remove the length from their start
		var length = bbcode.bbcode.length()
		for bb in bbcodes:
			if bb.offset_start > bbcode.start:
				bb.offset_start -= length
				bb.start -= length

		# Find any escaped brackets after this that need moving
		for i in range(0, escaped_open_brackets.size()):
			if escaped_open_brackets[i] > bbcode.start:
				escaped_open_brackets[i] -= length
		for i in range(0, escaped_close_brackets.size()):
			if escaped_close_brackets[i] > bbcode.start:
				escaped_close_brackets[i] -= length

		text = text.substr(0, index) + text.substr(index + length)
		next_bbcode_position = find_bbcode_positions_in_string(text, false)

	# Put the BB Codes back in
	for bb in bbcodes:
		text = text.insert(bb.start, bb.bbcode)

	# Put the escaped brackets back in
	for index in escaped_open_brackets:
		text = text.left(index) + "[" + text.right(text.length() - index - 1)
	for index in escaped_close_brackets:
		text = text.left(index) + "]" + text.right(text.length() - index - 1)

	return ResolvedLineData.new({
		text = text,
		pauses = pauses,
		speeds = speeds,
		mutations = mutations,
		time = time
	})


func find_bbcode_positions_in_string(string: String, find_all: bool = true) -> Array[Dictionary]:
	if not "[" in string: return []

	var positions: Array[Dictionary] = []

	var open_brace_count: int = 0
	var start: int = 0
	var bbcode: String = ""
	var code: String = ""
	var is_finished_code: bool = false
	for i in range(0, string.length()):
		if string[i] == "[":
			if open_brace_count == 0:
				start = i
				bbcode = ""
				code = ""
				is_finished_code = false
			open_brace_count += 1

		else:
			if not is_finished_code and (string[i].to_upper() != string[i] or string[i] == "/" or string[i] == "!"):
				code += string[i]
			else:
				is_finished_code = true

		if open_brace_count > 0:
			bbcode += string[i]

		if string[i] == "]":
			open_brace_count -= 1
			if open_brace_count == 0 and not code in ["if", "else", "/if"]:
				positions.append({
					bbcode = bbcode,
					code = code,
					start = start,
					raw_args = bbcode.substr(code.length() + 1, bbcode.length() - code.length() - 2).strip_edges()
				})

				if not find_all:
					return positions

	return positions


func tokenise(text: String, line_type: String, index: int) -> Array:
	var tokens: Array[Dictionary] = []
	var limit: int = 0
	while text.strip_edges() != "" and limit < 1000:
		limit += 1
		var found = find_match(text)
		if found.size() > 0:
			tokens.append({
				index = index,
				type = found.type,
				value = found.value
			})
			index += found.value.length()
			text = found.remaining_text
		elif text.begins_with(" "):
			index += 1
			text = text.substr(1)
		else:
			return build_token_tree_error(DialogueConstants.ERR_INVALID_EXPRESSION, index)

	return build_token_tree(tokens, line_type, "")[0]


func build_token_tree_error(error: int, index: int) -> Array:
	return [{ type = DialogueConstants.TOKEN_ERROR, value = error, index = index }]


func build_token_tree(tokens: Array[Dictionary], line_type: String, expected_close_token: String) -> Array:
	var tree: Array[Dictionary] = []
	var limit = 0
	while tokens.size() > 0 and limit < 1000:
		limit += 1
		var token = tokens.pop_front()

		var error = check_next_token(token, tokens, line_type, expected_close_token)
		if error != OK:
			return [build_token_tree_error(error, token.index), tokens]

		match token.type:
			DialogueConstants.TOKEN_FUNCTION:
				var sub_tree = build_token_tree(tokens, line_type, DialogueConstants.TOKEN_PARENS_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].value, token.index), tokens]

				tree.append({
					type = DialogueConstants.TOKEN_FUNCTION,
					# Consume the trailing "("
					function = token.value.substr(0, token.value.length() - 1),
					value = tokens_to_list(sub_tree[0])
				})
				tokens = sub_tree[1]

			DialogueConstants.TOKEN_DICTIONARY_REFERENCE:
				var sub_tree = build_token_tree(tokens, line_type, DialogueConstants.TOKEN_BRACKET_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].value, token.index), tokens]

				var args = tokens_to_list(sub_tree[0])
				if args.size() != 1:
					return [build_token_tree_error(DialogueConstants.ERR_INVALID_INDEX, token.index), tokens]

				tree.append({
					type = DialogueConstants.TOKEN_DICTIONARY_REFERENCE,
					# Consume the trailing "["
					variable = token.value.substr(0, token.value.length() - 1),
					value = args[0]
				})
				tokens = sub_tree[1]

			DialogueConstants.TOKEN_BRACE_OPEN:
				var sub_tree = build_token_tree(tokens, line_type, DialogueConstants.TOKEN_BRACE_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].value, token.index), tokens]

				var t = sub_tree[0]
				for i in range(0, t.size() - 2):
					# Convert Lua style dictionaries to string keys
					if t[i].type == DialogueConstants.TOKEN_VARIABLE and t[i+1].type == DialogueConstants.TOKEN_ASSIGNMENT:
						t[i].type = DialogueConstants.TOKEN_STRING
						t[i+1].type = DialogueConstants.TOKEN_COLON
						t[i+1].erase("value")

				tree.append({
					type = DialogueConstants.TOKEN_DICTIONARY,
					value = tokens_to_dictionary(sub_tree[0])
				})

				tokens = sub_tree[1]

			DialogueConstants.TOKEN_BRACKET_OPEN:
				var sub_tree = build_token_tree(tokens, line_type, DialogueConstants.TOKEN_BRACKET_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].value, token.index), tokens]

				var type = DialogueConstants.TOKEN_ARRAY
				var value = tokens_to_list(sub_tree[0])

				# See if this is referencing a nested dictionary value
				if tree.size() > 0:
					var previous_token = tree[tree.size() - 1]
					if previous_token.type in [DialogueConstants.TOKEN_DICTIONARY_REFERENCE, DialogueConstants.TOKEN_DICTIONARY_NESTED_REFERENCE]:
						type = DialogueConstants.TOKEN_DICTIONARY_NESTED_REFERENCE
						value = value[0]

				tree.append({
					type = type,
					value = value
				})
				tokens = sub_tree[1]

			DialogueConstants.TOKEN_PARENS_OPEN:
				var sub_tree = build_token_tree(tokens, line_type, DialogueConstants.TOKEN_PARENS_CLOSE)

				if sub_tree[0][0].type == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].value, token.index), tokens]

				tree.append({
					type = DialogueConstants.TOKEN_GROUP,
					value = sub_tree[0]
				})
				tokens = sub_tree[1]

			DialogueConstants.TOKEN_PARENS_CLOSE, \
			DialogueConstants.TOKEN_BRACE_CLOSE, \
			DialogueConstants.TOKEN_BRACKET_CLOSE:
				if token.type != expected_close_token:
					return [build_token_tree_error(DialogueConstants.ERR_UNEXPECTED_CLOSING_BRACKET, token.index), tokens]

				return [tree, tokens]

			DialogueConstants.TOKEN_NOT:
				# Double nots negate each other
				if tokens.size() > 0 and tokens.front().type == DialogueConstants.TOKEN_NOT:
					tokens.pop_front()
				else:
					tree.append({
						type = token.type
					})

			DialogueConstants.TOKEN_COMMA, \
			DialogueConstants.TOKEN_COLON, \
			DialogueConstants.TOKEN_DOT:
				tree.append({
					type = token.type
				})

			DialogueConstants.TOKEN_COMPARISON, \
			DialogueConstants.TOKEN_ASSIGNMENT, \
			DialogueConstants.TOKEN_OPERATOR, \
			DialogueConstants.TOKEN_AND_OR, \
			DialogueConstants.TOKEN_VARIABLE:
				var value = token.value.strip_edges()
				if value == "&&":
					value = "and"
				elif value == "||":
					value = "or"
				tree.append({
					type = token.type,
					value = value
				})

			DialogueConstants.TOKEN_STRING:
				tree.append({
					type = token.type,
					value = token.value.substr(1, token.value.length() - 2)
				})

			DialogueConstants.TOKEN_CONDITION:
				return [build_token_tree_error(DialogueConstants.ERR_UNEXPECTED_CONDITION, token.index), token]

			DialogueConstants.TOKEN_BOOL:
				tree.append({
					type = token.type,
					value = token.value.to_lower() == "true"
				})

			DialogueConstants.TOKEN_NUMBER:
				var value = token.value.to_float() if "." in token.value else token.value.to_int()
				# If previous token is a number and this one is a negative number then
				# inject a minus operator token in between them.
				if tree.size() > 0 and token.value.begins_with("-") and tree[tree.size() - 1].type == DialogueConstants.TOKEN_NUMBER:
					tree.append(({
						type = DialogueConstants.TOKEN_OPERATOR,
						value = "-"
					}))
					tree.append({
						type = token.type,
						value = -1 * value
					})
				else:
					tree.append({
						type = token.type,
						value = value
					})

	if expected_close_token != "":
		var index: int = tokens[0].index if tokens.size() > 0 else 0
		return [build_token_tree_error(DialogueConstants.ERR_MISSING_CLOSING_BRACKET, index), tokens]

	return [tree, tokens]


func check_next_token(token: Dictionary, next_tokens: Array[Dictionary], line_type: String, expected_close_token: String) -> Error:
	var next_token: Dictionary = { type = null }
	if next_tokens.size() > 0:
		next_token = next_tokens.front()

	# Guard for assigning in a condition. If the assignment token isn't inside a Lua dictionary
	# then it's an unexpected assignment in a condition line.
	if token.type == DialogueConstants.TOKEN_ASSIGNMENT and line_type == DialogueConstants.TYPE_CONDITION and not next_tokens.any(func(t): return t.type == expected_close_token):
		return DialogueConstants.ERR_UNEXPECTED_ASSIGNMENT

	# Special case for a negative number after this one
	if token.type == DialogueConstants.TOKEN_NUMBER and next_token.type == DialogueConstants.TOKEN_NUMBER and next_token.value.begins_with("-"):
		return OK

	var expected_token_types = []
	var unexpected_token_types = []
	match token.type:
		DialogueConstants.TOKEN_FUNCTION, \
		DialogueConstants.TOKEN_PARENS_OPEN:
			unexpected_token_types = [
				null,
				DialogueConstants.TOKEN_COMMA,
				DialogueConstants.TOKEN_COLON,
				DialogueConstants.TOKEN_COMPARISON,
				DialogueConstants.TOKEN_ASSIGNMENT,
				DialogueConstants.TOKEN_OPERATOR,
				DialogueConstants.TOKEN_AND_OR,
				DialogueConstants.TOKEN_DOT
			]

		DialogueConstants.TOKEN_BRACKET_CLOSE:
			unexpected_token_types = [
				DialogueConstants.TOKEN_NOT,
				DialogueConstants.TOKEN_BOOL,
				DialogueConstants.TOKEN_STRING,
				DialogueConstants.TOKEN_NUMBER,
				DialogueConstants.TOKEN_VARIABLE
			]

		DialogueConstants.TOKEN_BRACE_OPEN:
			expected_token_types = [
				DialogueConstants.TOKEN_STRING,
				DialogueConstants.TOKEN_VARIABLE,
				DialogueConstants.TOKEN_NUMBER,
				DialogueConstants.TOKEN_BRACE_CLOSE
			]

		DialogueConstants.TOKEN_PARENS_CLOSE, \
		DialogueConstants.TOKEN_BRACE_CLOSE:
			unexpected_token_types = [
				DialogueConstants.TOKEN_NOT,
				DialogueConstants.TOKEN_ASSIGNMENT,
				DialogueConstants.TOKEN_BOOL,
				DialogueConstants.TOKEN_STRING,
				DialogueConstants.TOKEN_NUMBER,
				DialogueConstants.TOKEN_VARIABLE
			]

		DialogueConstants.TOKEN_COMPARISON, \
		DialogueConstants.TOKEN_OPERATOR, \
		DialogueConstants.TOKEN_COMMA, \
		DialogueConstants.TOKEN_DOT, \
		DialogueConstants.TOKEN_NOT, \
		DialogueConstants.TOKEN_AND_OR, \
		DialogueConstants.TOKEN_DICTIONARY_REFERENCE:
			unexpected_token_types = [
				null,
				DialogueConstants.TOKEN_COMMA,
				DialogueConstants.TOKEN_COLON,
				DialogueConstants.TOKEN_COMPARISON,
				DialogueConstants.TOKEN_ASSIGNMENT,
				DialogueConstants.TOKEN_OPERATOR,
				DialogueConstants.TOKEN_AND_OR,
				DialogueConstants.TOKEN_PARENS_CLOSE,
				DialogueConstants.TOKEN_BRACE_CLOSE,
				DialogueConstants.TOKEN_BRACKET_CLOSE,
				DialogueConstants.TOKEN_DOT
			]

		DialogueConstants.TOKEN_COLON:
			unexpected_token_types = [
				DialogueConstants.TOKEN_COMMA,
				DialogueConstants.TOKEN_COLON,
				DialogueConstants.TOKEN_COMPARISON,
				DialogueConstants.TOKEN_ASSIGNMENT,
				DialogueConstants.TOKEN_OPERATOR,
				DialogueConstants.TOKEN_AND_OR,
				DialogueConstants.TOKEN_PARENS_CLOSE,
				DialogueConstants.TOKEN_BRACE_CLOSE,
				DialogueConstants.TOKEN_BRACKET_CLOSE,
				DialogueConstants.TOKEN_DOT
			]

		DialogueConstants.TOKEN_BOOL, \
		DialogueConstants.TOKEN_STRING, \
		DialogueConstants.TOKEN_NUMBER:
			unexpected_token_types = [
				DialogueConstants.TOKEN_NOT,
				DialogueConstants.TOKEN_ASSIGNMENT,
				DialogueConstants.TOKEN_BOOL,
				DialogueConstants.TOKEN_STRING,
				DialogueConstants.TOKEN_NUMBER,
				DialogueConstants.TOKEN_VARIABLE,
				DialogueConstants.TOKEN_FUNCTION,
				DialogueConstants.TOKEN_PARENS_OPEN,
				DialogueConstants.TOKEN_BRACE_OPEN,
				DialogueConstants.TOKEN_BRACKET_OPEN
			]

		DialogueConstants.TOKEN_VARIABLE:
			unexpected_token_types = [
				DialogueConstants.TOKEN_NOT,
				DialogueConstants.TOKEN_BOOL,
				DialogueConstants.TOKEN_STRING,
				DialogueConstants.TOKEN_NUMBER,
				DialogueConstants.TOKEN_VARIABLE,
				DialogueConstants.TOKEN_FUNCTION,
				DialogueConstants.TOKEN_PARENS_OPEN,
				DialogueConstants.TOKEN_BRACE_OPEN,
				DialogueConstants.TOKEN_BRACKET_OPEN
			]

	if (expected_token_types.size() > 0 and not next_token.type in expected_token_types or unexpected_token_types.size() > 0 and next_token.type in unexpected_token_types):
		match next_token.type:
			null:
				return DialogueConstants.ERR_UNEXPECTED_END_OF_EXPRESSION

			DialogueConstants.TOKEN_FUNCTION:
				return DialogueConstants.ERR_UNEXPECTED_FUNCTION

			DialogueConstants.TOKEN_PARENS_OPEN, \
			DialogueConstants.TOKEN_PARENS_CLOSE:
				return DialogueConstants.ERR_UNEXPECTED_BRACKET

			DialogueConstants.TOKEN_COMPARISON, \
			DialogueConstants.TOKEN_ASSIGNMENT, \
			DialogueConstants.TOKEN_OPERATOR, \
			DialogueConstants.TOKEN_NOT, \
			DialogueConstants.TOKEN_AND_OR:
				return DialogueConstants.ERR_UNEXPECTED_OPERATOR

			DialogueConstants.TOKEN_COMMA:
				return DialogueConstants.ERR_UNEXPECTED_COMMA
			DialogueConstants.TOKEN_COLON:
				return DialogueConstants.ERR_UNEXPECTED_COLON
			DialogueConstants.TOKEN_DOT:
				return DialogueConstants.ERR_UNEXPECTED_DOT

			DialogueConstants.TOKEN_BOOL:
				return DialogueConstants.ERR_UNEXPECTED_BOOLEAN
			DialogueConstants.TOKEN_STRING:
				return DialogueConstants.ERR_UNEXPECTED_STRING
			DialogueConstants.TOKEN_NUMBER:
				return DialogueConstants.ERR_UNEXPECTED_NUMBER
			DialogueConstants.TOKEN_VARIABLE:
				return DialogueConstants.ERR_UNEXPECTED_VARIABLE

		return DialogueConstants.ERR_INVALID_EXPRESSION

	return OK


func tokens_to_list(tokens: Array[Dictionary]) -> Array[Array]:
	var list: Array[Array] = []
	var current_item: Array[Dictionary] = []
	for token in tokens:
		if token.type == DialogueConstants.TOKEN_COMMA:
			list.append(current_item)
			current_item = []
		else:
			current_item.append(token)

	if current_item.size() > 0:
		list.append(current_item)

	return list


func tokens_to_dictionary(tokens: Array[Dictionary]) -> Dictionary:
	var dictionary = {}
	for i in range(0, tokens.size()):
		if tokens[i].type == DialogueConstants.TOKEN_COLON:
			if tokens.size() == i + 2:
				dictionary[tokens[i-1]] = tokens[i+1]
			else:
				dictionary[tokens[i-1]] = { type = DialogueConstants.TOKEN_GROUP, value = tokens.slice(i+1) }

	return dictionary


func find_match(input: String) -> Dictionary:
	for key in TOKEN_DEFINITIONS.keys():
		var regex = TOKEN_DEFINITIONS.get(key)
		var found = regex.search(input)
		if found:
			return {
				type = key,
				remaining_text = input.substr(found.strings[0].length()),
				value = found.strings[0]
			}

	return {}

tool
extends Node


const Constants = preload("res://addons/dialogue_manager/constants.gd")

const FUNCTION_VARIABLE_NUMBER_OR_STRING = "([a-zA-Z_][a-zA-Z_0-9]+\\(.*\\)|[a-zA-Z_][a-zA-Z_0-9]+|[\\-0-9\\.]+|\".+?\")"


export var _settings := NodePath()

onready var settings = get_node(_settings)

var TRANSLATION_REGEX := RegEx.new()
var MUTATION_REGEX := RegEx.new()
var CONDITION_REGEX := RegEx.new()
var WRAPPED_CONDITION_REGEX := RegEx.new()
var CONDITION_PARTS_REGEX := RegEx.new()
var REPLACEMENTS_REGEX := RegEx.new()
var GOTO_REGEX := RegEx.new()
var FUNCTION_REGEX := RegEx.new()
var BB_CODE_REGEX := RegEx.new()
var MARKER_CODE_REGEX := RegEx.new()


func _ready() -> void:
	TRANSLATION_REGEX.compile("\\[TR:(?<tr>.*?)\\]")
	MUTATION_REGEX.compile("(do|set) (?<lhs>" + FUNCTION_VARIABLE_NUMBER_OR_STRING + ") ?(?<operator>=|\\+=|-=|\\*=|\\/=)? ?(?<rhs>.+)?")
	WRAPPED_CONDITION_REGEX.compile("\\[if (?<condition>.*)\\]")
	CONDITION_REGEX.compile("(if|elif) (?<condition>.*)")
	CONDITION_PARTS_REGEX.compile("(?<lhs>" + FUNCTION_VARIABLE_NUMBER_OR_STRING + ") ?(?<operator>==|<=|>=|<|>|!=|<>|in)? ?(?<rhs>.+)?")
	REPLACEMENTS_REGEX.compile("{{(.*?)}}")
	GOTO_REGEX.compile("goto # (?<jump_to_title>.*)")
	FUNCTION_REGEX.compile("(?<function>[a-zA-Z_]+[a-zA-Z_0-9]*)\\((?<args>.*)\\)")
	BB_CODE_REGEX.compile("\\[[^\\]]+\\]")
	MARKER_CODE_REGEX.compile("\\[(?<code>wait|\\/?speed)(?<args>[^\\]]+)?\\]")


func parse(content: String) -> Dictionary:
	var dialogue: Dictionary = {}
	var errors: Array = []
	
	var titles: Dictionary = {}
	var known_translations = {}
	
	var parent_stack: Array = []
	
	var raw_lines = content.split("\n")
	
	# Find all titles first
	for id in range(0, raw_lines.size()):
		if raw_lines[id].begins_with("# "):
			var title = raw_lines[id].substr(2).strip_edges()
			if titles.has(title):
				errors.append(error(id, "Duplicate title"))
			else:
				var next_nonempty_line_id = get_next_nonempty_line_id(id, raw_lines)
				if next_nonempty_line_id != Constants.ID_NULL:
					titles[title] = next_nonempty_line_id
				else:
					titles[title] = Constants.ID_TITLE_HAS_NO_BODY
	
	# Then parse all lines
	for id in range(0, raw_lines.size()):
		var raw_line = raw_lines[id]
		
		var line: Dictionary = {
			"next_id": Constants.ID_NULL
		}
		
		# Ignore empty lines and comments
		if is_line_empty(raw_line): continue
		
		# Work out if we are inside a conditional or option or if we just
		# indented back out of one
		var indent_size = get_indent(raw_line)
		if indent_size < parent_stack.size():
			for _tab in range(0, parent_stack.size() - indent_size):
				parent_stack.pop_back()
		
		# If we are indented then this line should know about its parent
		if parent_stack.size() > 0:
			line["parent_id"] = parent_stack.back()
		
		# Trim any indentation (now that we've calculated it) so we can check
		# the begining of each line for its type
		raw_line = raw_line.strip_edges()
		
		# Grab translations
		var translation_key = extract_translation(raw_line)
		if translation_key != "":
			line["translation_key"] = translation_key
			raw_line = raw_line.replace("[TR:%s]" % translation_key, "")
		
		## Check for each kind of line
		
		# Response
		if raw_line.begins_with("- "):
			line["type"] = Constants.TYPE_RESPONSE
			parent_stack.append(str(id))
			if " [if " in raw_line:
				line["condition"] = extract_condition(raw_line, true)
			if " goto #" in raw_line:
				line["next_id"] = extract_goto(raw_line, titles)
			line["text"] = extract_response(raw_line)
			
			var previous_response_id = find_previous_response_id(id, raw_lines)
			if dialogue.has(previous_response_id):
				var previous_response = dialogue[previous_response_id]
				# Add this response to the list on the first response so that it is the 
				# authority on what is in the list of responses
				previous_response["responses"] = previous_response["responses"] + PoolStringArray([str(id)])
			else:
				# No previous response so this is the first in the list
				line["responses"] = PoolStringArray([str(id)])
			
			line["next_id_after"] = find_next_line_after_responses(id, raw_lines)

			# If this response has no body then the next id is the next id after
			if not line.has("next_id") or line.get("next_id") == Constants.ID_NULL:
				var next_nonempty_line_id = get_next_nonempty_line_id(id, raw_lines)
				if next_nonempty_line_id != Constants.ID_NULL:
					if get_indent(raw_lines[next_nonempty_line_id.to_int()]) <= indent_size:
						line["next_id"] = line.get("next_id_after")
					else:
						line["next_id"] = next_nonempty_line_id
				
			line["replacements"] = extract_dialogue_replacements(line.get("text"))
			if line.get("replacements").size() > 0 and line.get("replacements")[0].get("type") == Constants.TYPE_ERROR:
				errors.append(error(id, "Invalid expression"))
		
		# Title
		elif raw_line.begins_with("# "):
			line["type"] = Constants.TYPE_TITLE
			line["text"] = raw_line.replace("# ", "")
		
		# Condition
		elif raw_line.begins_with("if ") or raw_line.begins_with("elif "):
			parent_stack.append(str(id))
			line["type"] = Constants.TYPE_CONDITION
			line["condition"] = extract_condition(raw_line)
			line["next_id_after"] = find_next_line_after_conditions(id, raw_lines, dialogue)
			var next_sibling_id = find_next_condition_sibling(id, raw_lines)
			line["next_conditional_id"] = next_sibling_id if is_valid_id(next_sibling_id) else line.get("next_id_after")
		elif raw_line.begins_with("else"):
			parent_stack.append(str(id))
			line["type"] = Constants.TYPE_CONDITION
			line["next_id_after"] = find_next_line_after_conditions(id, raw_lines, dialogue)
			line["next_conditional_id"] = line["next_id_after"]
		
		# Mutation
		elif raw_line.begins_with("do "):
			line["type"] = Constants.TYPE_MUTATION
			line["mutation"] = extract_mutation(raw_line)
		elif raw_line.begins_with("set "):
			line["type"] = Constants.TYPE_MUTATION
			line["mutation"] = extract_mutation(raw_line)
		
		# Goto
		elif raw_line.begins_with("goto #"):
			line["type"] = Constants.TYPE_GOTO
			line["next_id"] = extract_goto(raw_line, titles)
		
		# Dialogue
		else:
			line["type"] = Constants.TYPE_DIALOGUE
			if ": " in raw_line:
				var bits = raw_line.strip_edges().split(": ")
				line["character"] = bits[0]
				line["text"] = bits[1]
			else:
				line["character"] = ""
				line["text"] = raw_line
			
			line["replacements"] = extract_dialogue_replacements(line.get("text"))
			if line.get("replacements").size() > 0 and line.get("replacements")[0].get("type") == Constants.TYPE_ERROR:
				errors.append(error(id, "Invalid expression"))
			
			# Extract any BB style codes out of the text
			var markers = extract_markers(line.get("text"))
			line["text"] = markers.get("text")
			line["pauses"] = markers.get("pauses")
			line["speeds"] = markers.get("speeds")
		
		# Work out where to go after this line
		if line.get("next_id") == Constants.ID_NULL:
			# Unless the next line is an outdent then we can assume
			# it comes next
			var next_nonempty_line_id = get_next_nonempty_line_id(id, raw_lines)
			if next_nonempty_line_id != Constants.ID_NULL \
				and indent_size <= get_indent(raw_lines[next_nonempty_line_id.to_int()]):
				# The next line is a title so we can end here
				if raw_lines[next_nonempty_line_id.to_int()].strip_edges().begins_with("# "):
					line["next_id"] = Constants.ID_END_CONVERSATION
				# Otherwise it's a normal line
				else:
					line["next_id"] = next_nonempty_line_id
			# Otherwise, we grab the ID from the parents next ID after children
			elif dialogue.has(line.get("parent_id")):
				line["next_id"] = dialogue[line.get("parent_id")].get("next_id_after")
		
		# Check for duplicate transaction keys
		if line.get("type") in [Constants.TYPE_DIALOGUE, Constants.TYPE_RESPONSE]:
			if line.has("translation_key"):
				if known_translations.has(line.get("translation_key")) and known_translations.get(line.get("translation_key")) != line.get("text"):
					errors.append(error(id, "Duplicate translation key"))
				else:
					known_translations[line.get("translation_key")] = line.get("text")
			else:
				# Default translations key
				if settings.get_editor_value("missing_translations_are_errors", false):
					errors.append(error(id, "Missing translation"))
				else:
					line["translation_key"] = line.get("text")
		
		## Error checking
		
		# Can't find goto
		match line.get("next_id"):
			Constants.ID_ERROR:
				errors.append(error(id, "Unknown title"))
			Constants.ID_TITLE_HAS_NO_BODY:
				errors.append(error(id, "Referenced node has no body"))
		
		# Line after condition isn't indented once to the right
		if line.get("type") == Constants.TYPE_CONDITION and is_valid_id(line.get("next_id")):
			var next_line = raw_lines[line.get("next_id").to_int()]
			if next_line != null and get_indent(next_line) != indent_size + 1:
				errors.append(error(line.get("next_id").to_int(), "Invalid indentation"))
		# Line after normal line is indented to the right
		elif line.get("type") in [Constants.TYPE_TITLE, Constants.TYPE_DIALOGUE, Constants.TYPE_MUTATION, Constants.TYPE_GOTO] and is_valid_id(line.get("next_id")):
			var next_line = raw_lines[line.get("next_id").to_int()]
			if next_line != null and get_indent(next_line) > indent_size:
				errors.append(error(line.get("next_id").to_int(), "Invalid indentation"))
		
		# Parsing condition failed
		if line.has("condition"):
			if line.get("condition").has("lhs_error"):
				errors.append(error(id, line.get("condition").get("lhs_error")))
			if line.get("condition").has("rhs_error"):
				errors.append(error(id, line.get("condition").get("rhs_error")))
			
		# Parsing mutation failed
		elif line.has("mutation"):
			if line.get("mutation").has("lhs_error"):
				errors.append(error(id, line.get("mutation").get("lhs_error")))
			if line.get("mutation").has("rhs_error"):
				errors.append(error(id, line.get("mutation").get("rhs_error")))
		
		# Line failed to parse at all
		if line.get("type") == Constants.TYPE_UNKNOWN:
			errors.append(error(id, "Unknown line syntax"))
		
		# Done!
		dialogue[str(id)] = line
	
	return {
		"titles": titles,
		"lines": dialogue,
		"errors": errors
	}


func error(line_number: int, message: String) -> Dictionary:
	return {
		"line": line_number,
		"message": message
	}


func is_valid_id(id: String) -> bool:
	return false if id in [Constants.ID_NULL, Constants.ID_ERROR, Constants.ID_END_CONVERSATION] else true


func is_line_empty(line: String) -> bool:
	line = line.strip_edges()
	
	if line == "": return true
	if line == "endif": return true
	if line.begins_with("//"): return true
	
	return false


func get_indent(line: String) -> int:
	return line.count("\t", 0, line.find(line.strip_edges()))


func get_next_nonempty_line_id(line_number: int, all_lines: Array) -> String:
	for i in range(line_number + 1, all_lines.size()):
		if not is_line_empty(all_lines[i]):
			return str(i)
	return Constants.ID_NULL
	

func find_previous_response_id(line_number: int, all_lines: Array) -> String:
	var line = all_lines[line_number]
	var indent_size = get_indent(line)
	
	# Look back up the list to find the previous response
	var last_found_response_id: String = str(line_number)
	for i in range(line_number - 1, -1, -1):
		line = all_lines[i]
		
		if is_line_empty(line): continue
		
		# If its a response at the same indent level then its a match
		if get_indent(line) <= indent_size:
			if line.strip_edges().begins_with("- "):
				last_found_response_id = str(i)
			else:
				return last_found_response_id
				
	# Return itself if nothing was found
	return last_found_response_id


func find_next_condition_sibling(line_number: int, all_lines: Array) -> String:
	var line = all_lines[line_number]
	var expected_indent = get_indent(line)

	# Look down the list and find an elif or else at the same indent level
	var last_valid_id: int = line_number
	for i in range(line_number + 1, all_lines.size()):
		line = all_lines[i]
		if is_line_empty(line): continue
		
		var l = line.strip_edges()
		if l.begins_with("# "):
			return Constants.ID_END_CONVERSATION
			
		elif get_indent(line) < expected_indent:
			return Constants.ID_NULL
		
		elif get_indent(line) == expected_indent:
			# Found an if, which begins a different block
			if l.begins_with("if"):
				return Constants.ID_NULL
			
			# Found what we're looking for
			elif (l.begins_with("elif ") or l.begins_with("else")):
				return str(i)
		
		last_valid_id = i
	
	return Constants.ID_NULL


func find_next_line_after_conditions(line_number: int, all_lines: Array, dialogue: Dictionary) -> String:
	var line = all_lines[line_number]
	var expected_indent = get_indent(line)
	
	# Look down the list for the first non condition line at the same or less indent level
	for i in range(line_number + 1, all_lines.size()):
		line = all_lines[i]
		
		if is_line_empty(line): continue
		
		var line_indent = get_indent(line)
		line = line.strip_edges()
		
		if line.begins_with("# "):
			return Constants.ID_END_CONVERSATION
			
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
				line = all_lines[p]
				line_indent = get_indent(line)
				if line_indent < expected_indent:
					return dialogue[str(p)].next_id_after
	
	return Constants.ID_END_CONVERSATION


func find_next_line_after_responses(line_number: int, all_lines: Array) -> String:
	var line = all_lines[line_number]
	var expected_indent = get_indent(line)

	# Find the first line after this one that has a smaller indent that isn't another option
	# If we hit a title or the eof then we give up
	for i in range(line_number + 1, all_lines.size()):
		line = all_lines[i]
		
		if is_line_empty(line): continue
		
		line = line.strip_edges()
		
		# We hit a title so the next line is the end of the conversation
		if line.begins_with("# "):
			return Constants.ID_END_CONVERSATION
		
		# Another option so we continue
		elif line.begins_with("- "):
			continue
		
		# Otherwise check the indent for an outdent
		else:
			line_number = i
			line = all_lines[line_number]
			if get_indent(line) == expected_indent:
				return str(line_number)
	
	# EOF so must be end of conversation
	return Constants.ID_END_CONVERSATION


func extract_translation(line: String) -> String:
	# Find a static translation key, eg. [TR:something]
	var found = TRANSLATION_REGEX.search(line)
	if found:
		return found.strings[found.names.get("tr")] 
	else:
		return ""


func extract_response(line: String) -> String:
	# Find just the text prompt from a response, ignoring any conditions or gotos
	line = line.replace("- ", "")
	if " [if " in line:
		line = line.substr(0, line.find(" [if "))
	if " goto #" in line:
		line = line.substr(0, line.find(" goto #"))
	
	return line.strip_edges()


func extract_mutation(line: String) -> Dictionary:
	var mutation := {}
	
	var found = MUTATION_REGEX.search(line)
	
	if not found:
		mutation["lhs_type"] = Constants.TYPE_ERROR
		mutation["lhs_error"] = "Invalid mutation"
		return mutation
	
	var lhs = found.strings[found.names.get("lhs")]
	if "(" in lhs:
		# Cannot assign to a function
		if found.names.has("operator") or found.names.has("rhs"):
			mutation["lhs_type"] = Constants.TYPE_ERROR
			return mutation
		
		var function = extract_function(lhs)
		if function.get("name") == "":
			mutation["lhs_type"] = Constants.TYPE_ERROR
			mutation["lhs_error"] = "Invalid function"
			return mutation
		mutation["lhs_type"] = Constants.TYPE_FUNCTION
		mutation["lhs_function"] = function.get("name")
		mutation["lhs_args"] = function.get("args")
	else:
		mutation["lhs_type"] = Constants.TYPE_EXPRESSION
		mutation["lhs"] = lhs.strip_edges()
	
	# Bad right hand side or missing operator
	if (found.names.has("operator") and not found.names.has("rhs")) \
		or (found.names.has("rhs") and not found.names.has("operator")):
		mutation["rhs_type"] = Constants.TYPE_ERROR
		return mutation
	
	# We have a valid operator and rhs
	if found.names.has("operator") and found.names.has("rhs"):
		mutation["operator"] = found.strings[found.names.get("operator")]
		var rhs = found.strings[found.names.get("rhs")]
		var rhs_function = extract_function(rhs)
		if rhs_function.get("name") != "":
			mutation["rhs_type"] = Constants.TYPE_FUNCTION
			mutation["rhs_function"] = rhs_function.get("name")
			mutation["rhs_args"] = rhs_function.get("args")
		else:
			mutation["rhs_type"] = Constants.TYPE_EXPRESSION
			var tokens = tokenise(rhs)
			if tokens[0].get("type") == Constants.TYPE_ERROR:
				mutation["rhs_type"] = Constants.TYPE_ERROR
				mutation["rhs_error"] = tokens[0].get("value")
			else:
				mutation["rhs"] = tokens
	
	# Error checking
	if mutation["lhs_type"] == Constants.TYPE_EXPRESSION and mutation["operator"] == "":
		mutation["rhs_type"] = Constants.TYPE_ERROR
		mutation["rhs_error"] = "Missing value"
	
	return mutation


func extract_condition(raw_line: String, is_wrapped: bool = false) -> Dictionary:
	var condition := {}
	
	var regex = WRAPPED_CONDITION_REGEX if is_wrapped else CONDITION_REGEX
	var found = regex.search(raw_line)
	
	if found == null:
		condition["lhs_type"] = Constants.TYPE_ERROR
		condition["lhs_error"] = "Incomplete condition"
		return condition
	
	var raw_condition = found.strings[found.names.get("condition")]
	
	# Split it into parts first
	found = CONDITION_PARTS_REGEX.search(raw_condition)
	
	var lhs = found.strings[found.names.get("lhs")]
	var lhs_function = extract_function(lhs)
	if lhs_function["name"] != "":
		condition["lhs_type"] = Constants.TYPE_FUNCTION
		condition["lhs_function"] = lhs_function.get("name")
		condition["lhs_args"] = lhs_function.get("args")
	else:
		condition["lhs_type"] = Constants.TYPE_EXPRESSION
		condition["lhs"] = lhs.strip_edges()
	
	# Bad right hand side or missing operator
	if (found.names.has("operator") and not found.names.has("rhs")) \
		or (found.names.has("rhs") and not found.names.has("operator")):
		condition["rhs_type"] = Constants.TYPE_ERROR
		condition["rhs_error"] = "Invalid comparison condition"
		return condition
	
	# We have a valid operator and rhs
	if found.names.has("operator") and found.names.has("rhs"):
		condition["operator"] = found.strings[found.names.get("operator")]
		var rhs = found.strings[found.names.get("rhs")]
		var rhs_function = extract_function(rhs)
		if rhs_function["name"]:
			condition["rhs_type"] = Constants.TYPE_FUNCTION
			condition["rhs_function"] = rhs_function.get("name")
			condition["rhs_args"] = rhs_function.get("args")
		else:
			condition["rhs_type"] = Constants.TYPE_EXPRESSION
			var tokens = tokenise(rhs)
			if tokens[0].get("type") == Constants.TYPE_ERROR:
				condition["rhs_type"] = Constants.TYPE_ERROR
				condition["rhs_error"] = tokens[0].get("value")
			else:
				condition["rhs"] = tokens
	
	return condition


func extract_function(string: String) -> Dictionary:
	var found = FUNCTION_REGEX.search(string)
	if not found:
		return {
			"name": "",
			"args": []
		}
	else:
		var args = found.strings[found.names.get("args")]
		return {
			"name": found.strings[found.names.get("function")],
			"args": [] if args == "" else args.split(", ")
		}


func extract_dialogue_replacements(text: String) -> Array:
	var founds = REPLACEMENTS_REGEX.search_all(text)
	
	if founds == null or founds.size() == 0: 
		return []
	
	var replacements: Array = []
	for found in founds:
		var value_in_text = found.strings[1]
		var replacement := {
			"value_in_text": "{{%s}}" % value_in_text
		}
		var function = extract_function(value_in_text)
		if function.get("name") != "":
			replacement["type"] = Constants.TYPE_FUNCTION
			replacement["function"] = function.get("name")
			replacement["args"] = function.get("args")
		else:
			replacement["type"] = Constants.TYPE_EXPRESSION
			var tokens = tokenise(value_in_text)
			if tokens[0].get("type") == Constants.TYPE_ERROR:
				replacement["type"] = Constants.TYPE_ERROR
				return [replacement]
			else:
				replacement["value"] = tokens
		
		replacements.append(replacement)
	
	return replacements
	

func extract_goto(line: String, titles: Dictionary) -> String:
	var found = GOTO_REGEX.search(line)
	
	if found == null: return Constants.ID_ERROR
	
	var title = found.strings[found.names.get("jump_to_title")]
	
	# "goto # END" means end the conversation
	if title == "END": 
		return Constants.ID_END_CONVERSATION
	elif titles.has(title):
		return titles.get(title)
	else:
		return Constants.ID_ERROR


func extract_markers(line: String) -> Dictionary:
	var text = line
	var pauses = {}
	var speeds = []
	var bb_codes = []
	var index_map = {}
	
	# Extract all of the BB codes so that we know the actual text (we could do this easier with
	# a RichTextLabel but then we'd need to await idle_frame which is annoying)
	var founds = BB_CODE_REGEX.search_all(text)
	if founds:
		for found in founds:
			var code = found.strings[0]
			# Ignore our own markers
			if code.begins_with("[wait") or code.begins_with("[speed") or code.begins_with("[/speed"):
				continue
			bb_codes.append([found.get_start(), code])

	for i in range(bb_codes.size() - 1, -1, -1):
		text.erase(bb_codes[i][0], bb_codes[i][1].length())
	
	var found = MARKER_CODE_REGEX.search(text)
	var limit = 0
	while found and limit < 1000:
		limit += 1
		var index = text.find(found.strings[0])
		var code = found.strings[found.names.get("code")]
		var raw_args = ""
		var args = {}
		if found.names.has("args"):
			# Could be something like:
			# 	"=1.0"
			# 	" rate=20 level=10"
			raw_args = found.strings[found.names.get("args")]
			if raw_args[0] == "=":
				raw_args = "value" + raw_args
			for pair in raw_args.strip_edges().split(" "):
				var bits = pair.split("=")
				args[bits[0]] = bits[1]
			
		match code:
			"wait":
				pauses[index] = args.get("value").to_float()
			"speed":
				speeds.append([index, args.get("value").to_float()])
			"/speed":
				speeds.append([index, 1.0])
		
		var length = found.strings[0].length()
		
		# Find any BB codes that are after this index and remove the length from their start
		for bb_code in bb_codes:
			if bb_code[0] > length:
				bb_code[0] -= length
		
		text.erase(index, length)
		found = MARKER_CODE_REGEX.search(text)
	
	# Put the BB Codes back in
	for bb_code in bb_codes:
		text = text.insert(bb_code[0], bb_code[1])
	
	return {
		"text": text,
		"pauses": pauses,
		"speeds": speeds
	}


func tokenise(input: String) -> Array:
	var tokens = []

	var values = RegEx.new()
	values.compile("[a-zA-Z_\\.0-9\" ]+")

	var brackets = RegEx.new()
	brackets.compile("\\(.*\\)")

	var operators = RegEx.new()
	operators.compile("(==|\\+=|\\-=|\\*=|\\/=|>=|>|<=|<|!=|<>| in |=|\\+|\\-|\\*|\\/)")

	var iterations = 0
	while input.length() > 0 and iterations < 1000:
		var first_char = input[0]
		
		if first_char == " ":
			input = input.substr(1)

		elif first_char == "(":
			var found_group = brackets.search(input)
			if found_group != null:
				var group = found_group.strings[0]
				tokens.append({ "type": "group", "value": tokenise(group.substr(1, group.length() - 2))})
				input = input.substr(group.length())
			else:
				return [{ "type": Constants.TYPE_ERROR, "value": "Unmatched braces"}]

		elif operators.search(first_char):
			tokens.append({ "type": "operator", "value": first_char })
			input = input.substr(1)

		else:
			var found_value = values.search(input)
			if found_value != null:
				var value = found_value.strings[0].strip_edges()
				tokens.append({ "type": "value", "value": value })
				input = input.substr(value.length())
			else:
				return [{ "type": Constants.TYPE_ERROR, "value": "Invalid value"}]

		iterations += 1
	
	# If the first token is a minus sign then add a 0 to the front
	if tokens[0].get("type") == "operator" and tokens[0].get("value") == "-":
		tokens = [{ "type": "value", "value": "0" }] + tokens

	# You can't end an expression with an operator
	if tokens[tokens.size() - 1].get("type") == "operator":
		return [{ "type": Constants.TYPE_ERROR, "value": "Incomplete expression"}]

	return tokens

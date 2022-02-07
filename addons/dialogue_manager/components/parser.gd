tool
extends Node


const Constants = preload("res://addons/dialogue_manager/constants.gd")


export var _settings := NodePath()

onready var settings = get_node(_settings)

var VALID_TITLE_REGEX := RegEx.new()
var TRANSLATION_REGEX := RegEx.new()
var MUTATION_REGEX := RegEx.new()
var CONDITION_REGEX := RegEx.new()
var WRAPPED_CONDITION_REGEX := RegEx.new()
var CONDITION_PARTS_REGEX := RegEx.new()
var REPLACEMENTS_REGEX := RegEx.new()
var GOTO_REGEX := RegEx.new()
var BB_CODE_REGEX := RegEx.new()
var MARKER_CODE_REGEX := RegEx.new()

var TOKEN_DEFINITIONS: Dictionary = {}


func _ready() -> void:
	VALID_TITLE_REGEX.compile("^[a-zA-Z_0-9]+$")
	TRANSLATION_REGEX.compile("\\[TR:(?<tr>.*?)\\]")
	MUTATION_REGEX.compile("(do|set) ((?<lhs>[a-z_A-Z][a-z_A-Z0-9]+) ?(?<operator>\\+=|-=|\\*=\\/=|=) ? (?<rhs>.*)|(?<function>[a-z_A-Z][a-z_A-Z0-9]+)\\((?<args>.*)\\))")
	WRAPPED_CONDITION_REGEX.compile("\\[if (?<condition>.*)\\]")
	CONDITION_REGEX.compile("(if|elif) (?<condition>.*)")
	REPLACEMENTS_REGEX.compile("{{(.*?)}}")
	GOTO_REGEX.compile("=> (?<jump_to_title>.*)")
	BB_CODE_REGEX.compile("\\[[^\\]]+\\]")
	MARKER_CODE_REGEX.compile("\\[(?<code>wait|\\/?speed|do |set )(?<args>[^\\]]+)?\\]")
	
	# Build our list of tokeniser tokens
	var tokens = {
		Constants.TOKEN_FUNCTION: "^[a-zA-Z_][a-zA-Z_0-9]+\\(",
		Constants.TOKEN_DICTIONARY_REFERENCE: "^[a-zA-Z_][a-zA-Z_0-9]+\\[",
		Constants.TOKEN_PARENS_OPEN: "^\\(",
		Constants.TOKEN_PARENS_CLOSE: "^\\)",
		Constants.TOKEN_BRACKET_OPEN: "^\\[",
		Constants.TOKEN_BRACKET_CLOSE: "^\\]",
		Constants.TOKEN_BRACE_OPEN: "^\\{",
		Constants.TOKEN_BRACE_CLOSE: "^\\}",
		Constants.TOKEN_COLON: "^:",
		Constants.TOKEN_COMPARISON: "^(==|<=|>=|<|>|!=|in )",
		Constants.TOKEN_NUMBER: "^\\-?\\d+(\\.\\d+)?",
		Constants.TOKEN_OPERATOR: "^(\\+|-|\\*|/)",
		Constants.TOKEN_COMMA: "^,",
		Constants.TOKEN_BOOL: "^(true|false)",
		Constants.TOKEN_AND_OR: "^(and|or)( |$)",
		Constants.TOKEN_STRING: "^\".*?\"",
		Constants.TOKEN_VARIABLE: "^[a-zA-Z_][a-zA-Z_0-9]+",
	}
	for key in tokens.keys():
		var regex = RegEx.new()
		regex.compile(tokens.get(key))
		TOKEN_DEFINITIONS[key] = regex


func parse(content: String) -> Dictionary:
	var dialogue: Dictionary = {}
	var errors: Array = []
	
	var titles: Dictionary = {}
	var known_translations = {}
	
	var parent_stack: Array = []
	
	var raw_lines = content.split("\n")
	
	# Find all titles first
	for id in range(0, raw_lines.size()):
		if raw_lines[id].begins_with("~ "):
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
			if " => " in raw_line:
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
			if line.get("replacements").size() > 0 and line.get("replacements")[0].has("error"):
				errors.append(error(id, "Invalid expression"))
		
		# Title
		elif raw_line.begins_with("~ "):
			line["type"] = Constants.TYPE_TITLE
			line["text"] = raw_line.replace("~ ", "")
			var valid_title = VALID_TITLE_REGEX.search(raw_line.substr(2).strip_edges())
			if not valid_title:
				errors.append(error(id, "Titles can only contain alphanumerics and underscores"))
		
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
		elif raw_line.begins_with("=> "):
			line["type"] = Constants.TYPE_GOTO
			line["next_id"] = extract_goto(raw_line, titles)
		
		# Dialogue
		else:
			line["type"] = Constants.TYPE_DIALOGUE
			var l = raw_line.replace("\\:", "!ESCAPED_COLON!")
			if ": " in l:
				var bits = Array(l.strip_edges().split(": "))
				line["character"] = bits.pop_front()
				line["text"] = PoolStringArray(bits).join(": ").replace("!ESCAPED_COLON!", ":")
			else:
				line["character"] = ""
				line["text"] = l.replace("!ESCAPED_COLON!", ":")
			
			line["replacements"] = extract_dialogue_replacements(line.get("text"))
			if line.get("replacements").size() > 0 and line.get("replacements")[0].has("error"):
				errors.append(error(id, "Invalid expression"))
			
			# Extract any BB style codes out of the text
			var markers = extract_markers(line.get("text"))
			line["text"] = markers.get("text")
			line["pauses"] = markers.get("pauses")
			line["speeds"] = markers.get("speeds")
			line["inline_mutations"] = markers.get("mutations")
		
		# Work out where to go after this line
		if line.get("next_id") == Constants.ID_NULL:
			# Unless the next line is an outdent then we can assume
			# it comes next
			var next_nonempty_line_id = get_next_nonempty_line_id(id, raw_lines)
			if next_nonempty_line_id != Constants.ID_NULL \
				and indent_size <= get_indent(raw_lines[next_nonempty_line_id.to_int()]):
				# The next line is a title so we can end here
				if raw_lines[next_nonempty_line_id.to_int()].strip_edges().begins_with("~ "):
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
		if line.has("condition") and line.get("condition").has("error"):
			errors.append(error(id, line.get("condition").get("error")))
			
		# Parsing mutation failed
		elif line.has("mutation") and line.get("mutation").has("error"):
			errors.append(error(id, line.get("mutation").get("error")))
		
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
	if line.begins_with("#"): return true
	
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
		if l.begins_with("~ "):
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
		
		if line.begins_with("~ "):
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
		if line.begins_with("~ "):
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
	if " =>" in line:
		line = line.substr(0, line.find(" =>"))
	
	return line.strip_edges()


func extract_mutation(line: String) -> Dictionary:
	var found = MUTATION_REGEX.search(line)
	
	if not found:
		return { "error": "Incomplete expression" }
	
	# If the mutation starts with a function then grab it and and parse
	# the args as expressions
	if found.names.has("function"):
		var expression = tokenise(found.strings[found.names.get("args")])
		if expression.size() > 0 and expression[0].get("type") == Constants.TYPE_ERROR:
			return { "error": expression[0].get("value") }

		return {
			"function": found.strings[found.names.get("function")],
			"args": tokens_to_list(expression)
		}
	
	# Otherwise we are setting a variable so expressionise its new value
	elif found.names.has("lhs"):
		var expression = tokenise(found.strings[found.names.get("rhs")])
		if expression[0].get("type") == Constants.TYPE_ERROR:
			return { "error": "Invalid expression for value" }
		
		return {
			"variable": found.strings[found.names.get("lhs")],
			"operator": found.strings[found.names.get("operator")],
			"expression": expression
		}
	
	else:
		return { "error": "Incomplete expression" }


func extract_condition(raw_line: String, is_wrapped: bool = false) -> Dictionary:
	var condition := {}
	
	var regex = WRAPPED_CONDITION_REGEX if is_wrapped else CONDITION_REGEX
	var found = regex.search(raw_line)
	
	if found == null:
		return { "error": "Incomplete condition" }
	
	var raw_condition = found.strings[found.names.get("condition")]
	var expression = tokenise(raw_condition)
	
	if expression[0].get("type") == Constants.TYPE_ERROR:
		return { "error": expression[0].get("value") }
	
	return {
		"expression": expression
	}


func extract_dialogue_replacements(text: String) -> Array:
	var founds = REPLACEMENTS_REGEX.search_all(text)
	
	if founds == null or founds.size() == 0: 
		return []
	
	var replacements: Array = []
	for found in founds:
		var replacement: Dictionary = {}
		var value_in_text = found.strings[1]
		var expression = tokenise(value_in_text)
		if expression[0].get("type") == Constants.TYPE_ERROR:
			replacement = { "error": expression[0].get("value") }
		else:
			replacement = {
				"value_in_text": "{{%s}}" % value_in_text,
				"expression": expression
			}
		replacements.append(replacement)
	
	return replacements
	

func extract_goto(line: String, titles: Dictionary) -> String:
	var found = GOTO_REGEX.search(line)
	
	if found == null: return Constants.ID_ERROR
	
	var title = found.strings[found.names.get("jump_to_title")].strip_edges()
	
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
	var mutations = []
	var bb_codes = []
	var index_map = {}
	
	# Extract all of the BB codes so that we know the actual text (we could do this easier with
	# a RichTextLabel but then we'd need to await idle_frame which is annoying)
	var founds = BB_CODE_REGEX.search_all(text)
	if founds:
		for found in founds:
			var code = found.strings[0]
			# Ignore our own markers
			if MARKER_CODE_REGEX.search(code):
				continue
			bb_codes.append([found.get_start(), code])

	for i in range(bb_codes.size() - 1, -1, -1):
		text.erase(bb_codes[i][0], bb_codes[i][1].length())
	
	var found = MARKER_CODE_REGEX.search(text)
	var limit = 0
	while found and limit < 1000:
		limit += 1
		var index = text.find(found.strings[0])
		var code = found.strings[found.names.get("code")].strip_edges()
		var raw_args = ""
		var args = {}
		if found.names.has("args"):
			raw_args = found.strings[found.names.get("args")]
			if code in ["do", "set"]:
				args["value"] = extract_mutation("%s %s" % [code, raw_args])
			else:
				# Could be something like:
				# 	"=1.0"
				# 	" rate=20 level=10"
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
			"do":
				mutations.append([index, args.get("value")])
		
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
		"speeds": speeds,
		"mutations": mutations
	}
		

func tokenise(text: String) -> Array:
	var tokens = []
	var limit = 0
	while text.strip_edges() != "" and limit < 1000:
		limit += 1
		var found = find_match(text)
		if found.size() > 0:
			tokens.append({
				"type": found.get("type"),
				"value": found.get("value")
			})
			text = found.get("remaining_text")
		elif text.begins_with(" "):
			text = text.substr(1)
		else:
			return [{ "type": "error", "value": "Invalid expression" }]
	
	return build_token_tree(tokens)[0]
	

func build_token_tree_error(message: String) -> Array:
	return [{ "type": Constants.TOKEN_ERROR, "value": message}]


func build_token_tree(tokens: Array, expected_close_token: String = "") -> Array:
	var tree = []
	var limit = 0
	while tokens.size() > 0 and limit < 1000:
		limit += 1
		var token = tokens.pop_front()
		
		var error = check_next_token(token, tokens)
		if error != "":
			return [build_token_tree_error(error), tokens]
		
		match token.type:
			Constants.TOKEN_FUNCTION:
				var sub_tree = build_token_tree(tokens, Constants.TOKEN_PARENS_CLOSE)
				
				if sub_tree[0].size() > 0 and sub_tree[0][0].get("type") == Constants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				tree.append({
					"type": Constants.TOKEN_FUNCTION,
					# Consume the trailing "("
					"function": token.get("value").substr(0, token.get("value").length() - 1),
					"value": tokens_to_list(sub_tree[0])
				})
				tokens = sub_tree[1]
			
			Constants.TOKEN_DICTIONARY_REFERENCE:
				var sub_tree = build_token_tree(tokens, Constants.TOKEN_BRACKET_CLOSE)
				
				if sub_tree[0].size() > 0 and sub_tree[0][0].get("type") == Constants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				var args = tokens_to_list(sub_tree[0])
				if args.size() != 1:
					return [build_token_tree_error("Invalid index"), tokens]
				
				tree.append({
					"type": Constants.TOKEN_DICTIONARY_REFERENCE,
					# Consume the trailing "["
					"variable": token.get("value").substr(0, token.get("value").length() - 1),
					"value": args[0]
				})
				tokens = sub_tree[1]
			
			Constants.TOKEN_BRACE_OPEN:
				var sub_tree = build_token_tree(tokens, Constants.TOKEN_BRACE_CLOSE)
				
				if sub_tree[0].size() > 0 and sub_tree[0][0].get("type") == Constants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				tree.append({
					"type": Constants.TOKEN_DICTIONARY,
					"value": tokens_to_dictionary(sub_tree[0])
				})
				tokens = sub_tree[1]
			
			Constants.TOKEN_BRACKET_OPEN:
				var sub_tree = build_token_tree(tokens, Constants.TOKEN_BRACKET_CLOSE)
				
				if sub_tree[0].size() > 0 and sub_tree[0][0].get("type") == Constants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				tree.append({
					"type": Constants.TOKEN_ARRAY,
					"value": tokens_to_list(sub_tree[0])
				})
				tokens = sub_tree[1]

			Constants.TOKEN_PARENS_OPEN:
				var sub_tree = build_token_tree(tokens, Constants.TOKEN_PARENS_CLOSE)
				
				if sub_tree[0][0].get("type") == Constants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				tree.append({
					"type": Constants.TOKEN_GROUP,
					"value": sub_tree[0]
				})
				tokens = sub_tree[1]

			Constants.TOKEN_PARENS_CLOSE, \
			Constants.TOKEN_BRACE_CLOSE, \
			Constants.TOKEN_BRACKET_CLOSE:
				if token.get("type") != expected_close_token:
					return [build_token_tree_error("Unexpected closing bracket"), tokens]
				
				return [tree, tokens]
			
			Constants.TOKEN_COMMA, \
			Constants.TOKEN_COLON:
				tree.append({
					"type": token.get("type")
				})
			
			Constants.TOKEN_COMPARISON, \
			Constants.TOKEN_OPERATOR, \
			Constants.TOKEN_AND_OR, \
			Constants.TOKEN_VARIABLE: \
				tree.append({
					"type": token.get("type"),
					"value": token.get("value").strip_edges()
				})
			
			Constants.TOKEN_STRING:
				tree.append({
					"type": token.get("type"),
					"value": token.get("value").substr(1, token.get("value").length() - 2)
				})
			
			Constants.TOKEN_BOOL:
				tree.append({
					"type": token.get("type"),
					"value": token.get("value").to_lower() == "true"
				})
			
			Constants.TOKEN_NUMBER:
				tree.append({
					"type": token.get("type"),
					"value": token.get("value").to_float() if "." in token.get("value") else token.get("value").to_int()
				})
	
	if expected_close_token != "":
		return [build_token_tree_error("Missing closing bracket"), tokens] 

	return [tree, tokens]


func check_next_token(token: Dictionary, next_tokens: Array) -> String:
	var next_token_type = null
	if next_tokens.size() > 0:
		next_token_type = next_tokens.front().get("type")
 
	var unexpected_token_types = []
	match token.get("type"):
		Constants.TOKEN_FUNCTION, \
		Constants.TOKEN_PARENS_OPEN:
			unexpected_token_types = [null, Constants.TOKEN_COMMA, Constants.TOKEN_COLON, Constants.TOKEN_COMPARISON, Constants.TOKEN_OPERATOR, Constants.TOKEN_AND_OR]
		
		Constants.TOKEN_PARENS_CLOSE, \
		Constants.TOKEN_BRACE_CLOSE, \
		Constants.TOKEN_BRACKET_CLOSE:
			unexpected_token_types = [Constants.TOKEN_BOOL, Constants.TOKEN_STRING, Constants.TOKEN_NUMBER, Constants.TOKEN_VARIABLE]

		Constants.TOKEN_COMPARISON, \
		Constants.TOKEN_OPERATOR, \
		Constants.TOKEN_COMMA, \
		Constants.TOKEN_COLON, \
		Constants.TOKEN_AND_OR, \
		Constants.TOKEN_DICTIONARY_REFERENCE:
			unexpected_token_types = [null, Constants.TOKEN_COMMA, Constants.TOKEN_COLON, Constants.TOKEN_COMPARISON, Constants.TOKEN_OPERATOR, Constants.TOKEN_AND_OR, Constants.TOKEN_PARENS_CLOSE, Constants.TOKEN_BRACE_CLOSE, Constants.TOKEN_BRACKET_CLOSE]

		Constants.TOKEN_BOOL, \
		Constants.TOKEN_STRING, \
		Constants.TOKEN_NUMBER, \
		Constants.TOKEN_VARIABLE:
			unexpected_token_types = [Constants.TOKEN_BOOL, Constants.TOKEN_STRING, Constants.TOKEN_NUMBER, Constants.TOKEN_VARIABLE, Constants.TOKEN_FUNCTION, Constants.TOKEN_PARENS_OPEN, Constants.TOKEN_BRACE_OPEN, Constants.TOKEN_BRACKET_OPEN]

	if next_token_type in unexpected_token_types:
		match next_token_type:
			null:
				return "Unexpected end of expression"

			Constants.TOKEN_FUNCTION:
				return "Unexpected function"

			Constants.TOKEN_PARENS_OPEN, \
			Constants.TOKEN_PARENS_CLOSE:
				return "Unexpected bracket"

			Constants.TOKEN_COMPARISON, \
			Constants.TOKEN_OPERATOR, \
			Constants.TOKEN_AND_OR:
				return "Unexpected operator"
			
			Constants.TOKEN_COMMA:
				return "Unexpected comma"
			Constants.TOKEN_COLON:
				return "Unexpected colon"

			Constants.TOKEN_BOOL:
				return "Unexpected boolean"
			Constants.TOKEN_STRING:
				return "Unexpected string"
			Constants.TOKEN_NUMBER:
				return "Unexpected number"
			Constants.TOKEN_VARIABLE:
				return "Unexpected variable"

			_:
				return "Invalid expression"

	return ""



func tokens_to_list(tokens: Array) -> Array:
	var list = []
	var current_item = []
	for token in tokens:
		if token.get("type") == Constants.TOKEN_COMMA:
			list.append(current_item)
			current_item = []
		else:
			current_item.append(token)
			
	if current_item.size() > 0:
		list.append(current_item)
		
	return list


func tokens_to_dictionary(tokens: Array) -> Dictionary:
	var dictionary = {}
	for i in range(0, tokens.size()):
		if tokens[i].get("type") == Constants.TOKEN_COLON:
			dictionary[tokens[i-1]] = tokens[i+1]
	
	return dictionary


func find_match(input: String) -> Dictionary:
	for key in TOKEN_DEFINITIONS.keys():
		var regex = TOKEN_DEFINITIONS.get(key)
		var found = regex.search(input)
		if found:
			return {
				"type": key,
				"remaining_text": input.substr(found.strings[0].length()),
				"value": found.strings[0]
			}
	
	return {}

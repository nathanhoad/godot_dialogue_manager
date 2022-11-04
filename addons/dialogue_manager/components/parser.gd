tool
extends Node


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


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

var WEIGHTED_RANDOM_SIBLINGS_REGEX: RegEx = RegEx.new()

var TOKEN_DEFINITIONS: Dictionary = {}


func _init() -> void:
	VALID_TITLE_REGEX.compile("^[^\\!\\@\\#\\$\\%\\^\\&\\*\\(\\)\\-\\=\\+\\{\\}\\[\\]\\;\\:\\\"\\'\\,\\.\\<\\>\\?\\/\\s]+$")
	TRANSLATION_REGEX.compile("\\[TR:(?<tr>.*?)\\]")
	MUTATION_REGEX.compile("(do|set) (?<mutation>.*)")
	WRAPPED_CONDITION_REGEX.compile("\\[if (?<condition>.*)\\]")
	CONDITION_REGEX.compile("(if|elif) (?<condition>.*)")
	REPLACEMENTS_REGEX.compile("{{(.*?)}}")
	GOTO_REGEX.compile("=><? (?<jump_to_title>.*)")
	
	WEIGHTED_RANDOM_SIBLINGS_REGEX.compile("^\\%(?<weight>\\d+)? ")
	
	# Build our list of tokeniser tokens
	var tokens = {
		DialogueConstants.TOKEN_FUNCTION: "^[a-zA-Z_][a-zA-Z_0-9]+\\(",
		DialogueConstants.TOKEN_DICTIONARY_REFERENCE: "^[a-zA-Z_][a-zA-Z_0-9]+\\[",
		DialogueConstants.TOKEN_PARENS_OPEN: "^\\(",
		DialogueConstants.TOKEN_PARENS_CLOSE: "^\\)",
		DialogueConstants.TOKEN_BRACKET_OPEN: "^\\[",
		DialogueConstants.TOKEN_BRACKET_CLOSE: "^\\]",
		DialogueConstants.TOKEN_BRACE_OPEN: "^\\{",
		DialogueConstants.TOKEN_BRACE_CLOSE: "^\\}",
		DialogueConstants.TOKEN_COLON: "^:",
		DialogueConstants.TOKEN_COMPARISON: "^(==|<=|>=|<|>|!=|in )",
		DialogueConstants.TOKEN_ASSIGNMENT: "^(\\+=|\\-=|\\*=|/=|=)",
		DialogueConstants.TOKEN_NUMBER: "^\\-?\\d+(\\.\\d+)?",
		DialogueConstants.TOKEN_OPERATOR: "^(\\+|\\-|\\*|/|%)",
		DialogueConstants.TOKEN_COMMA: "^,",
		DialogueConstants.TOKEN_DOT: "^\\.",
		DialogueConstants.TOKEN_BOOL: "^(true|false)",
		DialogueConstants.TOKEN_NOT: "^(not( |$)|!)",
		DialogueConstants.TOKEN_AND_OR: "^(and|or)( |$)",
		DialogueConstants.TOKEN_STRING: "^\".*?\"",
		DialogueConstants.TOKEN_VARIABLE: "^[a-zA-Z_][a-zA-Z_0-9]+",
		DialogueConstants.TOKEN_COMMMENT: "^#.*"
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
				if next_nonempty_line_id != DialogueConstants.ID_NULL:
					titles[title] = next_nonempty_line_id
				else:
					titles[title] = DialogueConstants.ID_TITLE_HAS_NO_BODY
	
	# Then parse all lines
	for id in range(0, raw_lines.size()):
		var raw_line = raw_lines[id]
		
		var line: Dictionary = {
			next_id = DialogueConstants.ID_NULL
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
		if is_response_line(raw_line):
			parent_stack.append(str(id))
			line["type"] = DialogueConstants.TYPE_RESPONSE
			if " [if " in raw_line:
				line["condition"] = extract_condition(raw_line, true)
			if " => " in raw_line:
				line["next_id"] = extract_goto(raw_line, titles)
			if " =>< " in raw_line:
				# Because of when the return point needs to be known at runtime we need to split
				# this line into two (otherwise the return point would be dependent on the balloon)
				var goto_line: Dictionary ={
					type = DialogueConstants.TYPE_GOTO,
					next_id = extract_goto(raw_line, titles),
					next_id_after = find_next_line_after_responses(id, raw_lines, dialogue, parent_stack),
					is_snippet = true
				}
				dialogue[str(id) + ".1"] = goto_line
				line["next_id"] = str(id) + ".1"
				
			line["text"] = extract_response_prompt(raw_line)
			
			var previous_response_id = find_previous_response_id(id, raw_lines)
			if dialogue.has(previous_response_id):
				var previous_response = dialogue[previous_response_id]
				# Add this response to the list on the first response so that it is the 
				# authority on what is in the list of responses
				previous_response["responses"] = previous_response["responses"] + PoolStringArray([str(id)])
			else:
				# No previous response so this is the first in the list
				line["responses"] = PoolStringArray([str(id)])
			
			line["next_id_after"] = find_next_line_after_responses(id, raw_lines, dialogue, parent_stack)

			# If this response has no body then the next id is the next id after
			if not line.has("next_id") or line.get("next_id") == DialogueConstants.ID_NULL:
				var next_nonempty_line_id = get_next_nonempty_line_id(id, raw_lines)
				if next_nonempty_line_id != DialogueConstants.ID_NULL:
					if get_indent(raw_lines[next_nonempty_line_id.to_int()]) <= indent_size:
						line["next_id"] = line.get("next_id_after")
					else:
						line["next_id"] = next_nonempty_line_id
				
			line["replacements"] = extract_dialogue_replacements(line.get("text"))
			if line.get("replacements").size() > 0 and line.get("replacements")[0].has("error"):
				errors.append(error(id, "Invalid expression"))
			
			# If this response has a character name in it then it will automatically be
			# injected as a line of dialogue if the player selects it
			var l = line.get("text").replace("\\:", "!ESCAPED_COLON!")
			if ": " in l:
				var first_child: Dictionary = { 
					type = DialogueConstants.TYPE_DIALOGUE, 
					next_id = line.get("next_id"),
					next_id_after = line.get("next_id_after"),
					replacements = line.get("replacements"),
					translation_key = line.get("translation_key")
				}
				
				var bits = Array(l.strip_edges().split(": "))
				first_child["character"] = bits.pop_front()
				# You can use variables in the character's name
				first_child["character_replacements"] = extract_dialogue_replacements(first_child.get("character"))
				if first_child.get("character_replacements").size() > 0 and first_child.get("character_replacements")[0].has("error"):
					errors.append(error(id, "Invalid expression in character name"))
				first_child["text"] = PoolStringArray(bits).join(": ").replace("!ESCAPED_COLON!", ":")
				
				line["character"] = first_child.get("character")
				line["text"] = first_child.get("text")
				
				if first_child.get("translation_key") == null:
					first_child["translation_key"] = first_child.get("text")
				
				dialogue[str(id) + ".2"] = first_child
				line["next_id"] = str(id) + ".2"
			else:
				line["text"] = l.replace("!ESCAPED_COLON!", ":")
		
		# Title
		elif is_title_line(raw_line):
			if not raw_lines[id].begins_with("~"):
				errors.append(error(id, "Titles cannot be nested"))
			else:
				line["type"] = DialogueConstants.TYPE_TITLE
				line["text"] = raw_line.replace("~ ", "")
				var valid_title = VALID_TITLE_REGEX.search(raw_line.substr(2).strip_edges())
				if not valid_title:
					errors.append(error(id, "Titles can only contain alphanumerics and underscores"))
		
		# Condition
		elif is_condition_line(raw_line, false):
			parent_stack.append(str(id))
			line["type"] = DialogueConstants.TYPE_CONDITION
			line["condition"] = extract_condition(raw_line)
			line["next_id_after"] = find_next_line_after_conditions(id, raw_lines, dialogue)
			var next_sibling_id = find_next_condition_sibling(id, raw_lines)
			line["next_conditional_id"] = next_sibling_id if is_valid_id(next_sibling_id) else line.get("next_id_after")
		elif is_condition_line(raw_line, true):
			parent_stack.append(str(id))
			line["type"] = DialogueConstants.TYPE_CONDITION
			line["next_id_after"] = find_next_line_after_conditions(id, raw_lines, dialogue)
			line["next_conditional_id"] = line["next_id_after"]
		
		# Mutation
		elif is_mutation_line(raw_line):
			line["type"] = DialogueConstants.TYPE_MUTATION
			line["mutation"] = extract_mutation(raw_line)
		
		# Goto
		elif is_goto_line(raw_line):
			line["type"] = DialogueConstants.TYPE_GOTO
			line["next_id"] = extract_goto(raw_line, titles)
			if is_goto_snippet_line(raw_line):
				line["is_snippet"] = true
				line["next_id_after"] = get_line_after_line(id, indent_size, line, raw_lines, dialogue)
		
		# Dialogue
		else:
			# Work out any weighted random siblings
			if raw_line.begins_with("%"):
				apply_weighted_random(id, raw_line, indent_size, line, raw_lines, dialogue)
				raw_line = WEIGHTED_RANDOM_SIBLINGS_REGEX.sub(raw_line, "")
			
			line["type"] = DialogueConstants.TYPE_DIALOGUE
			var l = raw_line.replace("\\:", "!ESCAPED_COLON!")
			if ": " in l:
				var bits = Array(l.strip_edges().split(": "))
				line["character"] = bits.pop_front()
				# You can use variables in the character's name
				line["character_replacements"] = extract_dialogue_replacements(line.get("character"))
				if line.get("character_replacements").size() > 0 and line.get("character_replacements")[0].has("error"):
					errors.append(error(id, "Invalid expression in character name"))
				line["text"] = PoolStringArray(bits).join(": ").replace("!ESCAPED_COLON!", ":")
			else:
				line["character"] = ""
				line["text"] = l.replace("!ESCAPED_COLON!", ":")
			
			line["replacements"] = extract_dialogue_replacements(line.get("text"))
			if line.get("replacements").size() > 0 and line.get("replacements")[0].has("error"):
				errors.append(error(id, "Invalid expression"))
			
			# Unescape any newlines
			line["text"] = line.get("text").replace("\\n", "\n")
		
		# Work out where to go after this line
		if line.get("next_id") == DialogueConstants.ID_NULL:
			line["next_id"] = get_line_after_line(id, indent_size, line, raw_lines, dialogue)
		
		# Check for duplicate translation keys
		if line.get("type") in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]:
			if line.has("translation_key"):
				if known_translations.has(line.get("translation_key")) and known_translations.get(line.get("translation_key")) != line.get("text"):
					errors.append(error(id, "Duplicate translation key"))
				else:
					known_translations[line.get("translation_key")] = line.get("text")
			else:
				# Default translations key
				if settings != null and settings.get_editor_value("missing_translations_are_errors", false):
					errors.append(error(id, "Missing translation"))
				else:
					line["translation_key"] = line.get("text")
		
		## Error checking
		
		# Can't find goto
		match line.get("next_id"):
			DialogueConstants.ID_ERROR:
				errors.append(error(id, "Unknown title"))
			DialogueConstants.ID_TITLE_HAS_NO_BODY:
				errors.append(error(id, "Referenced node has no body"))
		
		# Line after condition isn't indented once to the right
		if line.get("type") == DialogueConstants.TYPE_CONDITION:
			if is_valid_id(line.get("next_id")):
				var next_line = raw_lines[line.get("next_id").to_int()]
				if get_indent(next_line) != indent_size + 1:
					errors.append(error(line.get("next_id").to_int(), "Invalid indentation"))
			else:
				errors.append(error(id, "Conditional lines need at least one indented line below them"))
				
		# Line after normal line is indented to the right
		elif line.get("type") in [DialogueConstants.TYPE_TITLE, DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_MUTATION, DialogueConstants.TYPE_GOTO] and is_valid_id(line.get("next_id")):
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
		if line.get("type") == DialogueConstants.TYPE_UNKNOWN:
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


func will_continue_through_titles() -> bool:
	if is_instance_valid(settings):
		return settings.get_editor_value("continue_through_titles", false)
	else:
		return false


func is_title_line(line: String) -> bool:
	return line.strip_edges().begins_with("~ ")


func is_condition_line(line: String, include_else: bool = true) -> bool:
	line = line.strip_edges()
	if line.begins_with("if ") or line.begins_with("elif "): return true
	if include_else and line.begins_with("else"): return true
	return false


func is_mutation_line(line: String) -> bool:
	line = line.strip_edges()
	return line.begins_with("do ") or line.begins_with("set ")


func is_goto_line(line: String) -> bool:
	line = line.strip_edges()
	return line.begins_with("=> ") or line.begins_with("=>< ")


func is_goto_snippet_line(line: String) -> bool:
	return line.strip_edges().begins_with("=>< ")


func is_dialogue_line(line: String) -> bool:
	if is_response_line(line): return false
	if is_title_line(line): return false
	if is_condition_line(line, true): return false
	if is_mutation_line(line): return false
	if is_goto_line(line): return false
	return true


func is_response_line(line: String) -> bool:
	return line.strip_edges().begins_with("- ")
	

func is_valid_id(id: String) -> bool:
	return false if id in [DialogueConstants.ID_NULL, DialogueConstants.ID_ERROR, DialogueConstants.ID_END_CONVERSATION] else true


func is_line_empty(line: String) -> bool:
	line = line.strip_edges()
	
	if line == "": return true
	if line == "endif": return true
	if line.begins_with("#"): return true
	
	return false


func get_line_after_line(id: int, indent_size: int, line: Dictionary, raw_lines: Array, dialogue: Dictionary) -> String:
	# Unless the next line is an outdent we can assume it comes next
	var next_nonempty_line_id = get_next_nonempty_line_id(id, raw_lines)
	if next_nonempty_line_id != DialogueConstants.ID_NULL \
		and indent_size <= get_indent(raw_lines[next_nonempty_line_id.to_int()]):
		# The next line is a title so we can end here
		if is_title_line(raw_lines[next_nonempty_line_id.to_int()]):
			if line.get("type") == DialogueConstants.TYPE_GOTO:
				return DialogueConstants.ID_NULL
			elif will_continue_through_titles():
				return get_next_nonempty_line_id(next_nonempty_line_id.to_int(), raw_lines)
			else:
				return DialogueConstants.ID_NULL
		# Otherwise it's a normal line
		else:
			return next_nonempty_line_id
	# Otherwise, we grab the ID from the parents next ID after children
	elif dialogue.has(line.get("parent_id")):
		return dialogue[line.get("parent_id")].get("next_id_after")
	
	else:
		return DialogueConstants.ID_NULL


func get_indent(line: String) -> int:
	return line.count("\t", 0, line.find(line.strip_edges()))


func apply_weighted_random(id: int, raw_line: String, indent_size: int, line: Dictionary, raw_lines: Array, dialogue: Dictionary) -> void:
	var weight: int = 1
	var found = WEIGHTED_RANDOM_SIBLINGS_REGEX.search(raw_line)
	if found and found.names.has("weight"):
		weight = found.strings[found.names.weight].to_int()
	
	# Look back up the list to find the first weighted random line in this group
	var original_random_line: Dictionary = {}
	for i in range(id, 0, -1):
		if not raw_lines[i].strip_edges().begins_with("%") or get_indent(raw_lines[i]) != indent_size:
			break
		elif dialogue.has(str(i)) and dialogue[str(i)].has("siblings"):
			original_random_line = dialogue[str(i)]
	
	# Attach it to the original random line and work out where to go after the line
	if original_random_line.size() > 0:
		original_random_line["siblings"] += [{ weight = weight, id = str(id) }]
		line["next_id"] = original_random_line.next_id
	# Or set up this line as the original
	else:
		line["siblings"] = [{ weight = weight, id = str(id) }]
		# Find the last weighted random line in this group
		for i in range(id, raw_lines.size()):
			if i + 1 >= raw_lines.size():
				line["next_id"] = DialogueConstants.ID_END
				break
			if not raw_lines[i + 1].strip_edges().begins_with("%") or get_indent(raw_lines[i + 1]) != indent_size:
				line["next_id"] = get_line_after_line(i, indent_size, line, raw_lines, dialogue)
				break
	
	if line.next_id == DialogueConstants.ID_NULL:
		line["next_id"] = DialogueConstants.ID_END


func get_next_nonempty_line_id(line_number: int, all_lines: Array) -> String:
	for i in range(line_number + 1, all_lines.size()):
		if not is_line_empty(all_lines[i]):
			return str(i)
	return DialogueConstants.ID_NULL
	

func find_previous_response_id(line_number: int, all_lines: Array) -> String:
	var line = all_lines[line_number]
	var indent_size = get_indent(line)
	
	# Look back up the list to find the previous response
	var last_found_response_id: String = str(line_number)
	for i in range(line_number - 1, -1, -1):
		line = all_lines[i]
		
		if is_line_empty(line): continue
		
		# If its a response at the same indent level then its a match
		if get_indent(line) == indent_size:
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
		
		last_valid_id = i
	
	return DialogueConstants.ID_NULL


func find_next_line_after_conditions(line_number: int, all_lines: Array, dialogue: Dictionary) -> String:
	var line = all_lines[line_number]
	var expected_indent = get_indent(line)
	
	# Look down the list for the first non condition line at the same or less indent level
	for i in range(line_number + 1, all_lines.size()):
		line = all_lines[i]
		
		if is_line_empty(line): continue
		
		var line_indent = get_indent(line)
		line = line.strip_edges()
		
		if is_title_line(line):
			if will_continue_through_titles():
				return get_next_nonempty_line_id(i, all_lines)
			else:
				return DialogueConstants.ID_END_CONVERSATION
			
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
				if is_line_empty(line): continue
				line_indent = get_indent(line)
				if line_indent < expected_indent:
					return dialogue[str(p)].next_id_after
	
	return DialogueConstants.ID_END_CONVERSATION


func find_next_line_after_responses(line_number: int, all_lines: Array, dialogue: Dictionary, parent_stack: Array) -> String:
	var line = all_lines[line_number]
	var expected_indent = get_indent(line)

	# Find the first line after this one that has a smaller indent that isn't another option
	# If we hit a title or the eof then we give up
	for i in range(line_number + 1, all_lines.size()):
		line = all_lines[i]
		
		if is_line_empty(line): continue
		
		var indent = get_indent(line)
		
		line = line.strip_edges()
		
		# We hit a title so the next line is the end of the conversation
		if is_title_line(line):
			if will_continue_through_titles():
				return get_next_nonempty_line_id(i, all_lines)
			else:
				return DialogueConstants.ID_END_CONVERSATION
		
		# Another option
		elif line.begins_with("- "):
			if indent == expected_indent:
				# ...at the same level so we continue
				continue
			elif indent < expected_indent:
				# ...outdented so check the previous parent
				var previous_parent = parent_stack[parent_stack.size() - 2]
				return dialogue[str(previous_parent)].next_id_after
		
		# We're at the end of a conditional so jump back up to see what's after it
		elif line.begins_with("elif ") or line.begins_with("else"):
			for p in range(line_number - 1, -1, -1):
				line = all_lines[p]
				if is_line_empty(line): continue
				var line_indent = get_indent(line)
				if line_indent < expected_indent:
					return dialogue[str(p)].next_id_after
		
		# Otherwise check the indent for an outdent
		else:
			line_number = i
			line = all_lines[line_number]
			if get_indent(line) <= expected_indent:
				return str(line_number)
	
	# EOF so must be end of conversation
	return DialogueConstants.ID_END_CONVERSATION


func extract_translation(line: String) -> String:
	# Find a static translation key, eg. [TR:something]
	var found = TRANSLATION_REGEX.search(line)
	if found:
		return found.strings[found.names.get("tr")] 
	else:
		return ""


func extract_response_prompt(line: String) -> String:
	# Find just the text prompt from a response, ignoring any conditions or gotos
	line = line.replace("- ", "")
	if " [if " in line:
		line = line.substr(0, line.find(" [if "))
	if " =>" in line:
		line = line.substr(0, line.find(" =>"))
	
	# Without the translation key if there is one
	var translation_key = extract_translation(line)
	if translation_key:
		line = line.replace("[TR:%s]" % translation_key, "")
	
	return line.strip_edges()


func extract_mutation(line: String) -> Dictionary:
	var found = MUTATION_REGEX.search(line)
	
	if not found:
		return { "error": "Incomplete expression" }
	
	if found.names.has("mutation"):
		var expression = tokenise(found.strings[found.names.get("mutation")])
		if expression[0].get("type") == DialogueConstants.TYPE_ERROR:
			return { "error": "Invalid expression for value" }
		else:
			return { "expression": expression }
	
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
	
	if expression[0].get("type") == DialogueConstants.TYPE_ERROR:
		return { "error": expression[0].get("value") }
	else:
		return { "expression": expression }


func extract_dialogue_replacements(text: String) -> Array:
	var founds = REPLACEMENTS_REGEX.search_all(text)
	
	if founds == null or founds.size() == 0: 
		return []
	
	var replacements: Array = []
	for found in founds:
		var replacement: Dictionary = {}
		var value_in_text = found.strings[1]
		var expression = tokenise(value_in_text)
		if expression[0].get("type") == DialogueConstants.TYPE_ERROR:
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
	
	if found == null: return DialogueConstants.ID_ERROR
	
	var title = found.strings[found.names.get("jump_to_title")].strip_edges()
	
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


func extract_markers(line: String) -> Dictionary:
	var text = line
	var pauses = {}
	var speeds = []
	var mutations = []
	var bbcodes = []
	var index_map = {}
	var time = null
	
	# Extract all of the BB codes so that we know the actual text (we could do this easier with
	# a RichTextLabel but then we'd need to await idle_frame which is annoying)
	var bbcode_positions = find_bbcode_positions_in_string(text)
	var accumulaive_length_offset = 0
	for position in bbcode_positions:
		# Ignore our own markers
		if position.code in ["wait", "speed", "/speed", "do", "set", "next"]:
			continue
		
		bbcodes.append({
			bbcode = position.bbcode,
			start = position.start,
			offset_start = position.start - accumulaive_length_offset
		})
		accumulaive_length_offset += position.bbcode.length()

	for bb in bbcodes:
		text.erase(bb.offset_start, bb.bbcode.length())
	
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
		if code in ["do", "set"]:
			args["value"] = extract_mutation("%s %s" % [code, raw_args])
		elif raw_args.length() > 0:
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
				if pauses.has(index):
					pauses[index] += args.get("value").to_float()
				else:
					pauses[index] = args.get("value").to_float()
			"speed":
				speeds.append([index, args.get("value").to_float()])
			"/speed":
				speeds.append([index, 1.0])
			"do", "set":
				mutations.append([index, args.get("value")])
			"next":
				time = args.get("value") if args.has("value") else "0"
		
		# Find any BB codes that are after this index and remove the length from their start
		var length = bbcode.bbcode.length()
		for bb in bbcodes:
			if bb.offset_start >= bbcode.start:
				bb.offset_start -= length
				bb.start -= length
		
		text.erase(index, length)
		next_bbcode_position = find_bbcode_positions_in_string(text, false)
	
	# Put the BB Codes back in
	for bb in bbcodes:
		text = text.insert(bb.start, bb.bbcode)

	return {
		"text": text,
		"pauses": pauses,
		"speeds": speeds,
		"mutations": mutations,
		"time": time
	}


func find_bbcode_positions_in_string(string: String, find_all: bool = true) -> Array:
	if not "[" in string: return []
	
	var positions: Array = []
	
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
			if not is_finished_code and (string[i].to_upper() != string[i] or string[i] == "/"):
				code += string[i]
			else:
				is_finished_code = true
		
		if open_brace_count > 0:
			bbcode += string[i]
		
		if string[i] == "]":
			open_brace_count -= 1
			if open_brace_count == 0:
				positions.append({
					bbcode = bbcode,
					code = code,
					start = start,
					raw_args = bbcode.substr(code.length() + 1, bbcode.length() - code.length() - 2).strip_edges()
				})
				
				if not find_all:
					return positions
			
	return positions


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
	return [{ "type": DialogueConstants.TOKEN_ERROR, "value": message}]


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
			DialogueConstants.TOKEN_FUNCTION:
				var sub_tree = build_token_tree(tokens, DialogueConstants.TOKEN_PARENS_CLOSE)
				
				if sub_tree[0].size() > 0 and sub_tree[0][0].get("type") == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				tree.append({
					"type": DialogueConstants.TOKEN_FUNCTION,
					# Consume the trailing "("
					"function": token.get("value").substr(0, token.get("value").length() - 1),
					"value": tokens_to_list(sub_tree[0])
				})
				tokens = sub_tree[1]
			
			DialogueConstants.TOKEN_DICTIONARY_REFERENCE:
				var sub_tree = build_token_tree(tokens, DialogueConstants.TOKEN_BRACKET_CLOSE)
				
				if sub_tree[0].size() > 0 and sub_tree[0][0].get("type") == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				var args = tokens_to_list(sub_tree[0])
				if args.size() != 1:
					return [build_token_tree_error("Invalid index"), tokens]
				
				tree.append({
					"type": DialogueConstants.TOKEN_DICTIONARY_REFERENCE,
					# Consume the trailing "["
					"variable": token.get("value").substr(0, token.get("value").length() - 1),
					"value": args[0]
				})
				tokens = sub_tree[1]
			
			DialogueConstants.TOKEN_BRACE_OPEN:
				var sub_tree = build_token_tree(tokens, DialogueConstants.TOKEN_BRACE_CLOSE)
				
				if sub_tree[0].size() > 0 and sub_tree[0][0].get("type") == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				tree.append({
					"type": DialogueConstants.TOKEN_DICTIONARY,
					"value": tokens_to_dictionary(sub_tree[0])
				})
				tokens = sub_tree[1]
			
			DialogueConstants.TOKEN_BRACKET_OPEN:
				var sub_tree = build_token_tree(tokens, DialogueConstants.TOKEN_BRACKET_CLOSE)
				
				if sub_tree[0].size() > 0 and sub_tree[0][0].get("type") == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				var type = DialogueConstants.TOKEN_ARRAY
				var value = tokens_to_list(sub_tree[0])
				
				# See if this is referencing a nested dictionary value
				if tree.size() > 0:
					var previous_token = tree[tree.size() - 1]
					if previous_token.get("type") in [DialogueConstants.TOKEN_DICTIONARY_REFERENCE, DialogueConstants.TOKEN_DICTIONARY_NESTED_REFERENCE]:
						type = DialogueConstants.TOKEN_DICTIONARY_NESTED_REFERENCE
						value = value[0]
				
				tree.append({
					"type": type,
					"value": value
				})
				tokens = sub_tree[1]

			DialogueConstants.TOKEN_PARENS_OPEN:
				var sub_tree = build_token_tree(tokens, DialogueConstants.TOKEN_PARENS_CLOSE)
				
				if sub_tree[0][0].get("type") == DialogueConstants.TOKEN_ERROR:
					return [build_token_tree_error(sub_tree[0][0].get("value")), tokens]
				
				tree.append({
					"type": DialogueConstants.TOKEN_GROUP,
					"value": sub_tree[0]
				})
				tokens = sub_tree[1]

			DialogueConstants.TOKEN_PARENS_CLOSE, \
			DialogueConstants.TOKEN_BRACE_CLOSE, \
			DialogueConstants.TOKEN_BRACKET_CLOSE:
				if token.get("type") != expected_close_token:
					return [build_token_tree_error("Unexpected closing bracket"), tokens]
				
				return [tree, tokens]
			
			DialogueConstants.TOKEN_NOT:
				# Double nots negate each other
				if tokens.size() > 0 and tokens.front().get("type") == DialogueConstants.TOKEN_NOT:
					tokens.pop_front()
				else:
					tree.append({
						"type": token.get("type")
					})
				
			DialogueConstants.TOKEN_COMMA, \
			DialogueConstants.TOKEN_COLON, \
			DialogueConstants.TOKEN_DOT:
				tree.append({
					"type": token.get("type")
				})
			
			DialogueConstants.TOKEN_COMPARISON, \
			DialogueConstants.TOKEN_ASSIGNMENT, \
			DialogueConstants.TOKEN_OPERATOR, \
			DialogueConstants.TOKEN_AND_OR, \
			DialogueConstants.TOKEN_VARIABLE: \
				tree.append({
					"type": token.get("type"),
					"value": token.get("value").strip_edges()
				})
			
			DialogueConstants.TOKEN_STRING:
				tree.append({
					"type": token.get("type"),
					"value": token.get("value").substr(1, token.get("value").length() - 2)
				})
			
			DialogueConstants.TOKEN_BOOL:
				tree.append({
					"type": token.get("type"),
					"value": token.get("value").to_lower() == "true"
				})
			
			DialogueConstants.TOKEN_NUMBER:
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
		DialogueConstants.TOKEN_COLON, \
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

	if next_token_type in unexpected_token_types:
		match next_token_type:
			null:
				return "Unexpected end of expression"

			DialogueConstants.TOKEN_FUNCTION:
				return "Unexpected function"

			DialogueConstants.TOKEN_PARENS_OPEN, \
			DialogueConstants.TOKEN_PARENS_CLOSE:
				return "Unexpected bracket"

			DialogueConstants.TOKEN_COMPARISON, \
			DialogueConstants.TOKEN_ASSIGNMENT, \
			DialogueConstants.TOKEN_OPERATOR, \
			DialogueConstants.TOKEN_NOT, \
			DialogueConstants.TOKEN_AND_OR:
				return "Unexpected operator"
			
			DialogueConstants.TOKEN_COMMA:
				return "Unexpected comma"
			DialogueConstants.TOKEN_COLON:
				return "Unexpected colon"
			DialogueConstants.TOKEN_DOT:
				return "Unexpected dot"

			DialogueConstants.TOKEN_BOOL:
				return "Unexpected boolean"
			DialogueConstants.TOKEN_STRING:
				return "Unexpected string"
			DialogueConstants.TOKEN_NUMBER:
				return "Unexpected number"
			DialogueConstants.TOKEN_VARIABLE:
				return "Unexpected variable"

			_:
				return "Invalid expression"

	return ""



func tokens_to_list(tokens: Array) -> Array:
	var list = []
	var current_item = []
	for token in tokens:
		if token.get("type") == DialogueConstants.TOKEN_COMMA:
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
		if tokens[i].get("type") == DialogueConstants.TOKEN_COLON:
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

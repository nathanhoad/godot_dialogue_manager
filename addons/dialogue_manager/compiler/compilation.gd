## A single compilation instance of some dialogue.
class_name DMCompilation extends RefCounted


#region Compilation locals


## A list of file paths that were imported by this file.
var imported_paths: PackedStringArray = []
## A list of state names from "using" clauses.
var using_states: PackedStringArray = []
## A map of titles in this file.
var titles: Dictionary = {}
## The first encountered title in this file.
var first_title: String = ""
## A list of character names in this file.
var character_names: PackedStringArray = []
## A list of any compilation errors.
var errors: Array[Dictionary] = []
## A map of all compiled lines.
var lines: Dictionary = {}
## A flattened and simplified map of compiled lines for storage in a resource.
var data: Dictionary = {}


#endregion

#region Internal variables


# A list of all [RegEx] references
var regex: DMCompilerRegEx = DMCompilerRegEx.new()
# For parsing condition/mutation expressions
var expression_parser: DMExpressionParser = DMExpressionParser.new()

# A map of titles that came from imported files.
var _imported_titles: Dictionary = {}
# Used to keep track of circular imports.
var _imported_line_map: Dictionary = {}
# The number of imported lines.
var _imported_line_count: int = 0
# A list of already encountered static line IDs.
var _known_translation_keys: Dictionary = {}
# A noop for retrieving the next line without conditions.
var _first: Callable = func(_s): return true

# Title jumps are adjusted as they are parsed so any goto lines might need to be adjusted after they are first seen.
var _goto_lines: Dictionary = {}


#endregion

#region Main


## Compile some text.
func compile(text: String, path: String = ".") -> Error:
	titles = {}
	character_names = []

	parse_line_tree(build_line_tree(inject_imported_files(text + "\n=> END", path)))

	# Convert the compiles lines to a Dictionary so they can be stored.
	for id in lines:
		var line: DMCompiledLine = lines[id]
		data[id] = line.to_data()

	if errors.size() > 0:
		return ERR_PARSE_ERROR

	return OK


## Inject any imported files
func inject_imported_files(text: String, path: String) -> PackedStringArray:
	# Work out imports
	var known_imports: Dictionary = {}

	# Include the base file path so that we can get around circular dependencies
	known_imports[path.hash()] = "."

	var raw_lines: PackedStringArray = text.split("\n")

	for id in range(0, raw_lines.size()):
		var line = raw_lines[id]
		if is_import_line(line):
			var import_data: Dictionary = extract_import_path_and_name(line)

			if not import_data.has("path"): continue

			var import_hash: int = import_data.path.hash()
			if import_data.size() > 0:
				# Keep track of titles so we can add imported ones later
				if str(import_hash) in _imported_titles.keys():
					add_error(id, 0, DMConstants.ERR_FILE_ALREADY_IMPORTED)
				if import_data.prefix in _imported_titles.values():
					add_error(id, 0, DMConstants.ERR_DUPLICATE_IMPORT_NAME)
				_imported_titles[str(import_hash)] = import_data.prefix

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

	if imported_content == "":
		_imported_line_count = 0
		return text.split("\n")
	else:
		_imported_line_count = cummulative_line_number + 1
		# Combine imported lines with the original lines
		return (imported_content + "\n" + text).split("\n")


## Import content from another dialogue file or return an ERR
func import_content(path: String, prefix: String, imported_line_map: Dictionary, known_imports: Dictionary) -> Error:
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content: PackedStringArray = file.get_as_text().strip_edges().split("\n")

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

					_imported_titles[import.prefix] = import.path.hash()

		var origin_hash: int = -1
		for hash_value in known_imports.keys():
			if known_imports[hash_value] == ".":
				origin_hash = hash_value

		# Replace any titles or jump points with references to the files they point to (event if they point to their own file)
		for i in range(0, content.size()):
			var line = content[i]
			if line.strip_edges().begins_with("~ "):
				var indent: String = "\t".repeat(get_indent(line))
				var title = line.strip_edges().substr(2)
				if "/" in line:
					var bits = title.split("/")
					content[i] = "%s~ %s/%s" % [indent, _imported_titles[bits[0]], bits[1]]
				else:
					content[i] = "%s~ %s/%s" % [indent, str(path.hash()), title]

			elif "=>< " in line:
				var jump: String = line.substr(line.find("=>< ") + "=>< ".length()).strip_edges()
				if "/" in jump:
					var bits: PackedStringArray = jump.split("/")
					var title_hash: int = _imported_titles[bits[0]]
					if title_hash == origin_hash:
						content[i] = "%s=>< %s" % [line.split("=>< ")[0], bits[1]]
					else:
						content[i] = "%s=>< %s/%s" % [line.split("=>< ")[0], title_hash, bits[1]]

				elif not jump in ["END", "END!"] and not jump.begins_with("{{"):
					content[i] = "%s=>< %s/%s" % [line.split("=>< ")[0], str(path.hash()), jump]

			elif "=> " in line:
				var jump: String = line.substr(line.find("=> ") + "=> ".length()).strip_edges()
				if "/" in jump:
					var bits: PackedStringArray = jump.split("/")
					var title_hash: int = _imported_titles[bits[0]]
					if title_hash == origin_hash:
						content[i] = "%s=> %s" % [line.split("=> ")[0], bits[1]]
					else:
						content[i] = "%s=> %s/%s" % [line.split("=> ")[0], title_hash, bits[1]]

				elif not jump in ["END", "END!"] and not jump.begins_with("{{"):
					content[i] = "%s=> %s/%s" % [line.split("=> ")[0], str(path.hash()), jump]

		imported_paths.append(path)
		known_imports[path.hash()] = "\n".join(content) + "\n=> END\n"
		return OK
	else:
		return ERR_FILE_NOT_FOUND


## Build a tree of parent/child relationships
func build_line_tree(raw_lines: PackedStringArray) -> DMTreeLine:
	var root: DMTreeLine = DMTreeLine.new("")
	var parent_chain: Array[DMTreeLine] = [root]
	var previous_line: DMTreeLine
	var doc_comments: PackedStringArray = []

	# Get list of known autoloads
	var autoload_names: PackedStringArray = get_autoload_names()

	for i in range(0, raw_lines.size()):
		var raw_line: String = raw_lines[i]
		var tree_line: DMTreeLine = DMTreeLine.new(str(i - _imported_line_count))

		tree_line.line_number = i + 1
		tree_line.type = get_line_type(raw_line)
		tree_line.text = raw_line.strip_edges()

		# Handle any "using" directives.
		if tree_line.type == DMConstants.TYPE_USING:
			var using_match: RegExMatch = regex.USING_REGEX.search(raw_line)
			if "state" in using_match.names:
				var using_state: String = using_match.strings[using_match.names.state].strip_edges()
				if not using_state in autoload_names:
					add_error(tree_line.line_number, 0, DMConstants.ERR_UNKNOWN_USING)
				elif not using_state in using_states:
					using_states.append(using_state)
				continue
		# Ignore import lines because they've already been processed.
		elif is_import_line(raw_line):
			continue

		tree_line.indent = get_indent(raw_line)

		# Attach doc comments
		if raw_line.strip_edges().begins_with("##"):
			doc_comments.append(raw_line.replace("##", "").strip_edges())
		elif tree_line.type == DMConstants.TYPE_DIALOGUE:
			tree_line.notes = "\n".join(doc_comments)
			doc_comments.clear()

		# Empty lines are only kept so that we can work out groupings of things (eg. randomised
		# lines). Therefore we only need to keep one empty line in a row even if there
		# are multiple. The indent of an empty line is assumed to be the same as the non-empty line
		# following it. That way, grouping calculations should work.
		if tree_line.type in [DMConstants.TYPE_UNKNOWN, DMConstants.TYPE_COMMENT] and raw_lines.size() > i + 1:
			var next_line = raw_lines[i + 1]
			if get_line_type(next_line) in [DMConstants.TYPE_UNKNOWN, DMConstants.TYPE_COMMENT]:
				continue
			else:
				tree_line.type = DMConstants.TYPE_UNKNOWN
				tree_line.indent = get_indent(next_line)

		# Nothing should be more than a single indent past its parent.
		if tree_line.indent > parent_chain.size():
			add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_INVALID_INDENTATION)

		# Check for indentation changes
		if tree_line.indent > parent_chain.size() - 1:
			parent_chain.append(previous_line)
		elif tree_line.indent < parent_chain.size() - 1:
			parent_chain.resize(tree_line.indent + 1)

		# Add any titles to the list of known titles
		if tree_line.type == DMConstants.TYPE_TITLE:
			var title: String = tree_line.text.substr(2)
			if title == "":
				add_error(i, 2, DMConstants.ERR_EMPTY_TITLE)
			elif titles.has(title):
				add_error(i, 2, DMConstants.ERR_DUPLICATE_TITLE)
			else:
				titles[title] = tree_line.id
				if "/" in title:
					# Replace the hash title with something human readable.
					var bits: PackedStringArray = title.split("/")
					if _imported_titles.has(bits[0]):
						title = _imported_titles[bits[0]] + "/" + bits[1]
						titles[title] = tree_line.id
				elif first_title == "" and i >= _imported_line_count:
					first_title = tree_line.id

		# Append the current line to the current parent (note: the root is the most basic parent).
		var parent: DMTreeLine = parent_chain[parent_chain.size() - 1]
		tree_line.parent = weakref(parent)
		parent.children.append(tree_line)

		previous_line = tree_line

	return root


#endregion

#region Parsing


func parse_line_tree(root: DMTreeLine, parent: DMCompiledLine = null) -> Array[DMCompiledLine]:
	var compiled_lines: Array[DMCompiledLine] = []

	for i in range(0, root.children.size()):
		var tree_line: DMTreeLine = root.children[i]
		var line: DMCompiledLine = DMCompiledLine.new(tree_line.id, tree_line.type)

		match line.type:
			DMConstants.TYPE_UNKNOWN:
				line.next_id = get_next_matching_sibling_id(root.children, i, parent, _first)

			DMConstants.TYPE_TITLE:
				parse_title_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_CONDITION:
				parse_condition_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_WHILE:
				parse_while_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_MATCH:
				parse_match_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_WHEN:
				parse_when_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_MUTATION:
				parse_mutation_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_GOTO:
				# Extract any weighted random calls before parsing dialogue
				if tree_line.text.begins_with("%"):
					parse_random_line(tree_line, line, root.children, i, parent)
				parse_goto_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_RESPONSE:
				parse_response_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_RANDOM:
				parse_random_line(tree_line, line, root.children, i, parent)

			DMConstants.TYPE_DIALOGUE:
				# Extract any weighted random calls before parsing dialogue
				if tree_line.text.begins_with("%"):
					parse_random_line(tree_line, line, root.children, i, parent)
				parse_dialogue_line(tree_line, line, root.children, i, parent)

		# Main line map is keyed by ID
		lines[line.id] = line

		# Returned lines order is preserved so that it can be used for compiling children
		compiled_lines.append(line)

	return compiled_lines


## Parse a title and apply it to the given line
func parse_title_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	var result: Error = OK

	line.text = tree_line.text.substr(tree_line.text.find("~ ") + 2).strip_edges()

	# Titles can't have numbers as the first letter (unless they are external titles which get replaced with hashes)
	if tree_line.line_number >= _imported_line_count and regex.BEGINS_WITH_NUMBER_REGEX.search(line.text):
		result = add_error(tree_line.line_number, 2, DMConstants.ERR_TITLE_BEGINS_WITH_NUMBER)

	# Only import titles are allowed to have "/" in them
	var valid_title = regex.VALID_TITLE_REGEX.search(line.text.replace("/", ""))
	if not valid_title:
		result = add_error(tree_line.line_number, 2, DMConstants.ERR_TITLE_INVALID_CHARACTERS)

	line.next_id = get_next_matching_sibling_id(siblings, sibling_index, parent, _first)

	## Update the titles reference to point to the actual first line
	titles[line.text] = line.next_id

	## Update any lines that point to this title
	if _goto_lines.has(line.text):
		for goto_line in _goto_lines[line.text]:
			goto_line.next_id = line.next_id

	return result


## Parse a goto and apply it to the given line.
func parse_goto_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	# Work out where this line is jumping to.
	var goto_data: DMResolvedGotoData = DMResolvedGotoData.new(tree_line.text, titles)
	if goto_data.error:
		return add_error(tree_line.line_number, tree_line.indent + 2, goto_data.error)
	if goto_data.next_id or goto_data.expression:
		line.next_id = goto_data.next_id
		line.next_id_expression = goto_data.expression
		add_reference_to_title(goto_data.title, line)

	if goto_data.is_snippet:
		line.is_snippet = true
		line.next_id_after = get_next_matching_sibling_id(siblings, sibling_index, parent, _first)

	return OK


## Parse a condition line and apply to the given line
func parse_condition_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	# Work out the next IDs before parsing the condition line itself so that the last
	# child can inherit from the chain.

	# Find the next conditional sibling that is part of this grouping (if there is one).
	for next_sibling: DMTreeLine in siblings.slice(sibling_index + 1):
		if not next_sibling.type in [DMConstants.TYPE_UNKNOWN, DMConstants.TYPE_CONDITION]:
			break
		elif next_sibling.type == DMConstants.TYPE_CONDITION:
			if next_sibling.text.begins_with("el"):
				line.next_sibling_id = next_sibling.id
				break
			else:
				break

	line.next_id_after = get_next_matching_sibling_id(siblings, sibling_index, parent, func(s: DMTreeLine):
		# The next line that isn't a conditional or is a new "if"
		return s.type != DMConstants.TYPE_CONDITION or s.text.begins_with("if ")
	)
	# Any empty IDs should end the conversation.
	if line.next_id_after == DMConstants.ID_NULL:
		line.next_id_after = parent.next_id_after if parent != null and parent.next_id_after else DMConstants.ID_END

	# Having no nested body is an immediate failure.
	if tree_line.children.size() == 0:
		return add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_INVALID_CONDITION_INDENTATION)

	# Try to parse the conditional expression ("else" has no expression).
	if "if " in tree_line.text:
		var condition: Dictionary = extract_condition(tree_line.text, false, tree_line.indent)
		if condition.has("error"):
			return add_error(tree_line.line_number, condition.index, condition.error)
		else:
			line.expression = condition

	# Parse any nested body lines
	parse_children(tree_line, line)

	return OK


## Parse a while loop and apply it to the given line.
func parse_while_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	line.next_id_after = get_next_matching_sibling_id(siblings, sibling_index, parent, _first)

	# Parse the while condition
	var condition: Dictionary = extract_condition(tree_line.text, false, tree_line.indent)
	if condition.has("error"):
		return add_error(tree_line.line_number, condition.index, condition.error)
	else:
		line.expression = condition

	# Parse the nested body (it should take care of looping back to this line when it finishes)
	parse_children(tree_line, line)

	return OK


func parse_match_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	var result: Error = OK

	# The next line after is the next sibling
	line.next_id_after = get_next_matching_sibling_id(siblings, sibling_index, parent, _first)

	# Extract the condition to match to
	var condition: Dictionary = extract_condition(tree_line.text, false, tree_line.indent)
	if condition.has("error"):
		result = add_error(tree_line.line_number, condition.index, condition.error)
	else:
		line.expression = condition

	# Match statements should have children
	if tree_line.children.size() == 0:
		result = add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_INVALID_CONDITION_INDENTATION)

	# Check that all children are when or else.
	for child in tree_line.children:
		if child.type == DMConstants.TYPE_WHEN: continue
		if child.type == DMConstants.TYPE_UNKNOWN: continue
		if child.type == DMConstants.TYPE_CONDITION and child.text.begins_with("else"): continue

		result = add_error(child.line_number, child.indent, DMConstants.ERR_EXPECTED_WHEN_OR_ELSE)

	# Each child should be a "when" or "else". We don't need those lines themselves, just their
	# condition and the line they point to if the conditions passes.
	var children: Array[DMCompiledLine] = parse_children(tree_line, line)
	for child: DMCompiledLine in children:
		# "when" cases
		if child.type == DMConstants.TYPE_WHEN:
			line.siblings.append({
				condition = child.expression,
				next_id = child.next_id
			})
		# "else" case
		elif child.type == DMConstants.TYPE_CONDITION:
			if line.siblings.any(func(s): return s.has("is_else")):
				result = add_error(child.line_number, child.indent, DMConstants.ERR_ONLY_ONE_ELSE_ALLOWED)
			else:
				line.siblings.append({
					next_id = child.next_id,
					is_else = true
				})
		# Remove the line from the list of all lines because we don't need it any more.
		lines.erase(child.id)

	return result


func parse_when_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	var result: Error = OK

	# This when line should be found inside a match line
	if parent.type != DMConstants.TYPE_MATCH:
		result = add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_WHEN_MUST_BELONG_TO_MATCH)

	# When lines should have children
	if tree_line.children.size() == 0:
		result = add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_INVALID_CONDITION_INDENTATION)

	# The next line after a when is the same as its parent match line
	line.next_id_after = parent.next_id_after

	# Extract the condition to match to
	var condition: Dictionary = extract_condition(tree_line.text, false, tree_line.indent)
	if condition.has("error"):
		result = add_error(tree_line.line_number, condition.index, condition.error)
	else:
		line.expression = condition

	parse_children(tree_line, line)

	return result


## Parse a mutation line and apply it to the given line
func parse_mutation_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	var mutation: Dictionary = extract_mutation(tree_line.text)
	if mutation.has("error"):
		return add_error(tree_line.line_number, mutation.index, mutation.error)
	else:
		line.expression = mutation

	line.next_id = get_next_matching_sibling_id(siblings, sibling_index, parent, _first)

	return OK


## Parse a response and apply it to the given line.
func parse_response_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	var result: Error = OK

	# Remove the "- "
	tree_line.text = tree_line.text.substr(2)

	# Extract the static line ID
	var static_line_id: String = extract_static_line_id(tree_line.text)
	if static_line_id:
		tree_line.text = tree_line.text.replace("[ID:%s]" % [static_line_id], "")
		line.translation_key = static_line_id

	# Handle conditional responses and remove them from the prompt text.
	if " [if " in tree_line.text:
		var condition = extract_condition(tree_line.text, true, tree_line.indent)
		if condition.has("error"):
			result = add_error(tree_line.line_number, condition.index, condition.error)
		else:
			line.expression = condition
			# Extract just the raw condition text
			var found: RegExMatch = regex.WRAPPED_CONDITION_REGEX.search(tree_line.text)
			line.expression_text = found.strings[found.names.expression]

			tree_line.text = regex.WRAPPED_CONDITION_REGEX.sub(tree_line.text, "").strip_edges()

	# Find the original response in this group of responses.
	var original_response: DMTreeLine = tree_line
	for i in range(sibling_index - 1, -1, -1):
		if siblings[i].type == DMConstants.TYPE_RESPONSE:
			original_response = siblings[i]
		elif siblings[i].type != DMConstants.TYPE_UNKNOWN:
			break

	# If it's the original response then set up an original line.
	if original_response == tree_line:
		line.next_id_after = get_next_matching_sibling_id(siblings, sibling_index, parent, (func(s: DMTreeLine):
			# The next line that isn't a response.
			return not s.type in [DMConstants.TYPE_RESPONSE, DMConstants.TYPE_UNKNOWN]
		), true)
		line.responses = [line.id]
		# If this line has children then the next ID is the first child.
		if tree_line.children.size() > 0:
			parse_children(tree_line, line)
		# Otherwise use the same ID for after the random group.
		else:
			line.next_id = line.next_id_after
	# Otherwise let the original line know about it.
	else:
		var original_line: DMCompiledLine = lines[original_response.id]
		line.next_id_after = original_line.next_id_after
		line.siblings = original_line.siblings
		original_line.responses.append(line.id)
		# If this line has children then the next ID is the first child.
		if tree_line.children.size() > 0:
			parse_children(tree_line, line)
		# Otherwise use the original line's next ID after.
		else:
			line.next_id = original_line.next_id_after

	parse_character_and_dialogue(tree_line, line, siblings, sibling_index, parent)

	return OK


## Parse a randomised line
func parse_random_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	# Find the weight
	var weight: float = 1
	var found = regex.WEIGHTED_RANDOM_SIBLINGS_REGEX.search(tree_line.text + " ")
	var condition: Dictionary = {}
	if found:
		if found.names.has("weight"):
			weight = found.strings[found.names.weight].to_float()
		if found.names.has("condition"):
			condition = extract_condition(tree_line.text, true, tree_line.indent)

	# Find the original random sibling. It will be the jump off point.
	var original_sibling: DMTreeLine = tree_line
	for i in range(sibling_index - 1, -1, -1):
		if siblings[i] and siblings[i].is_random:
			original_sibling = siblings[i]
		else:
			break

	var weighted_sibling: Dictionary = { weight = weight, id = line.id, condition = condition }

	# If it's the original sibling then set up an original line.
	if original_sibling == tree_line:
		line.next_id_after = get_next_matching_sibling_id(siblings, sibling_index, parent, (func(s: DMTreeLine):
			# The next line that isn't a randomised line.
			# NOTE: DMTreeLine.is_random won't be set at this point so we need to check for the "%" prefix.
			return not s.text.begins_with("%")
		), true)
		line.siblings = [weighted_sibling]
		# If this line has children then the next ID is the first child.
		if tree_line.children.size() > 0:
			parse_children(tree_line, line)
		# Otherwise use the same ID for after the random group.
		else:
			line.next_id = line.next_id_after

	# Otherwise let the original line know about it.
	else:
		var original_line: DMCompiledLine = lines[original_sibling.id]
		line.next_id_after = original_line.next_id_after
		line.siblings = original_line.siblings
		original_line.siblings.append(weighted_sibling)
		# If this line has children then the next ID is the first child.
		if tree_line.children.size() > 0:
			parse_children(tree_line, line)
		# Otherwise use the original line's next ID after.
		else:
			line.next_id = original_line.next_id_after

	# Remove the randomise syntax from the line.
	tree_line.text = regex.WEIGHTED_RANDOM_SIBLINGS_REGEX.sub(tree_line.text, "")
	tree_line.is_random = true

	return OK


## Parse some dialogue and apply it to the given line.
func parse_dialogue_line(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	var result: Error = OK

	# Remove escape character
	if tree_line.text.begins_with("\\using"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\if"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\elif"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\else"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\while"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\match"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\when"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\do"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\set"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\-"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\~"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\=>"): tree_line.text = tree_line.text.substr(1)
	if tree_line.text.begins_with("\\%"): tree_line.text = tree_line.text.substr(1)

	# Append any further dialogue
	for i in range(0, tree_line.children.size()):
		var child: DMTreeLine = tree_line.children[i]
		if child.type == DMConstants.TYPE_DIALOGUE:
			# Nested dialogue lines cannot have further nested dialogue.
			if child.children.size() > 0:
				add_error(child.children[0].line_number, child.children[0].indent, DMConstants.ERR_INVALID_INDENTATION)
			# Mark this as a dialogue child of another dialogue line.
			child.is_nested_dialogue = true
			var child_line = DMCompiledLine.new("", DMConstants.TYPE_DIALOGUE)
			parse_character_and_dialogue(child, child_line, [], 0, parent)
			var child_static_line_id: String = extract_static_line_id(child.text)
			if child_line.character != "" or child_static_line_id != "":
				add_error(child.line_number, child.indent, DMConstants.ERR_UNEXPECTED_SYNTAX_ON_NESTED_DIALOGUE_LINE)
			# Check that only the last child (or none) has a jump reference
			if i < tree_line.children.size() - 1 and " =>" in child.text:
				add_error(child.line_number, child.indent, DMConstants.ERR_NESTED_DIALOGUE_INVALID_JUMP)
			if i == 0 and " =>" in tree_line.text:
				add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_NESTED_DIALOGUE_INVALID_JUMP)

			tree_line.text += "\n" + child.text
		elif child.type == DMConstants.TYPE_UNKNOWN:
			tree_line.text += "\n"
		else:
			result = add_error(child.line_number, child.indent, DMConstants.ERR_INVALID_INDENTATION)

	# Extract the static line ID
	var static_line_id: String = extract_static_line_id(tree_line.text)
	if static_line_id:
		tree_line.text = tree_line.text.replace(" [ID:", "[ID:").replace("[ID:%s]" % [static_line_id], "")
		line.translation_key = static_line_id

	# Check for simultaneous lines
	if tree_line.text.begins_with("| "):
		# Jumps are only allowed on the origin line.
		if " =>" in tree_line.text:
			result = add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_GOTO_NOT_ALLOWED_ON_CONCURRECT_LINES)
		# Check for a valid previous line.
		tree_line.text = tree_line.text.substr(2)
		var previous_sibling: DMTreeLine = siblings[sibling_index - 1]
		if previous_sibling.type != DMConstants.TYPE_DIALOGUE:
			result = add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_CONCURRENT_LINE_WITHOUT_ORIGIN)
		else:
			# Because the previous line's concurrent_lines array is the same as
			# any line before that this doesn't need to check any higher up.
			var previous_line: DMCompiledLine = lines[previous_sibling.id]
			previous_line.concurrent_lines.append(line.id)
			line.concurrent_lines = previous_line.concurrent_lines

	parse_character_and_dialogue(tree_line, line, siblings, sibling_index, parent)

	# Check for any inline expression errors
	var resolved_line_data: DMResolvedLineData = DMResolvedLineData.new("")
	var bbcodes: Array[Dictionary] = resolved_line_data.find_bbcode_positions_in_string(tree_line.text, true, true)
	for bbcode: Dictionary in bbcodes:
		var tag: String = bbcode.code
		var code: String = bbcode.raw_args
		if tag.begins_with("$>") or tag.begins_with("do") or tag.begins_with("set") or tag.begins_with("if"):
			var expression: Array = expression_parser.tokenise(code, DMConstants.TYPE_MUTATION, bbcode.start + bbcode.code.length())
			if expression.size() == 0:
				add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_INVALID_EXPRESSION)
			elif expression[0].type == DMConstants.TYPE_ERROR:
				add_error(tree_line.line_number, tree_line.indent + expression[0].i, expression[0].value)

	# If the line isn't part of a weighted random group then make it point to the next
	# available sibling.
	if line.next_id == DMConstants.ID_NULL and line.siblings.size() == 0:
		line.next_id = get_next_matching_sibling_id(siblings, sibling_index, parent, func(s: DMTreeLine):
			# Ignore concurrent lines.
			return not s.text.begins_with("| ")
		)

	return result


## Parse the character name and dialogue and apply it to a given line.
func parse_character_and_dialogue(tree_line: DMTreeLine, line: DMCompiledLine, siblings: Array[DMTreeLine], sibling_index: int, parent: DMCompiledLine) -> Error:
	var result: Error = OK

	var text: String = tree_line.text

	# Attach any doc comments.
	line.notes = tree_line.notes

	# Extract tags.
	var tag_data: DMResolvedTagData = DMResolvedTagData.new(text)
	line.tags = tag_data.tags
	text = tag_data.text_without_tags

	# Handle inline gotos and remove them from the prompt text.
	if " =><" in text:
		# Because of when the return point needs to be known at runtime we need to split
		# this line into two (otherwise the return point would be dependent on the balloon).
		var goto_data: DMResolvedGotoData = DMResolvedGotoData.new(text, titles)
		if goto_data.error:
			result = add_error(tree_line.line_number, tree_line.indent + 3, goto_data.error)
		if goto_data.next_id or goto_data.expression:
			text = goto_data.text_without_goto
			var goto_line: DMCompiledLine = DMCompiledLine.new(line.id + ".1", DMConstants.TYPE_GOTO)
			goto_line.next_id = goto_data.next_id
			line.next_id_expression = goto_data.expression
			if line.type == DMConstants.TYPE_RESPONSE:
				goto_line.next_id_after = get_next_matching_sibling_id(siblings, sibling_index, parent, func(s: DMTreeLine):
					# If this is coming from a response then we want the next non-response line.
					return s.type != DMConstants.TYPE_RESPONSE
				)
			else:
				goto_line.next_id_after = get_next_matching_sibling_id(siblings, sibling_index, parent, _first)
			goto_line.is_snippet = true
			lines[goto_line.id] = goto_line
			line.next_id = goto_line.id
			add_reference_to_title(goto_data.title, goto_line)
	elif " =>" in text:
		var goto_data: DMResolvedGotoData = DMResolvedGotoData.new(text, titles)
		if goto_data.error:
			result = add_error(tree_line.line_number, tree_line.indent + 2, goto_data.error)
		if goto_data.next_id or goto_data.expression:
			text = goto_data.text_without_goto
			line.next_id = goto_data.next_id
			line.next_id_expression = goto_data.expression
			add_reference_to_title(goto_data.title, line)

	# Handle the dialogue.
	text = text.replace("\\:", "!ESCAPED_COLON!")
	if ": " in text:
		# If a character was given then split it out.
		var bits = Array(text.strip_edges().split(": "))
		line.character = bits.pop_front().strip_edges()
		if not line.character in character_names:
			character_names.append(line["character"])
		# Character names can have expressions in them.
		line.character_replacements = expression_parser.extract_replacements(line.character, tree_line.indent)
		for replacement in line.character_replacements:
			if replacement.has("error"):
				result = add_error(tree_line.line_number, replacement.index, replacement.error)
		text = ": ".join(bits).replace("!ESCAPED_COLON!", ":")
	else:
		line.character = ""
		text = text.replace("!ESCAPED_COLON!", ":")

	# Extract any expressions in the dialogue.
	line.text_replacements = expression_parser.extract_replacements(text, line.character.length() + 2 + tree_line.indent)
	for replacement in line.text_replacements:
		if replacement.has("error"):
			result = add_error(tree_line.line_number, replacement.index, replacement.error)

	# Replace any newlines.
	text = text.replace("\\n", "\n").strip_edges()

	# If there was no manual translation key then just use the text itself (unless this is a
	# child dialogue below another dialogue line).
	if not tree_line.is_nested_dialogue and line.translation_key == "":
		# Show an error if missing translations is enabled
		if DMSettings.get_setting(DMSettings.MISSING_TRANSLATIONS_ARE_ERRORS, false):
			result = add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_MISSING_ID)
		else:
			line.translation_key = text

	line.text = text

	# IDs can't be duplicated for text that doesn't match.
	if line.translation_key != "":
		if _known_translation_keys.has(line.translation_key) and _known_translation_keys.get(line.translation_key) != line.text:
			result = add_error(tree_line.line_number, tree_line.indent, DMConstants.ERR_DUPLICATE_ID)
		else:
			_known_translation_keys[line.translation_key] = line.text

	return result


#endregion

#region Errors


## Add a compilation error to the list. Returns the given error code.
func add_error(line_number: int, column_number: int, error: int) -> Error:
	# See if the error was in an imported file
	for item in _imported_line_map.values():
		if line_number < item.to_line:
			errors.append({
				line_number = item.imported_on_line_number,
				column_number = 0,
				error = DMConstants.ERR_ERRORS_IN_IMPORTED_FILE,
				external_error = error,
				external_line_number = line_number
			})
			return error

	# Otherwise, it's in this file
	errors.append({
		line_number = line_number - _imported_line_count,
		column_number = column_number,
		error = error
	})

	return error


#endregion

#region Helpers


## Get the names of any autoloads in the project.
func get_autoload_names() -> PackedStringArray:
	var autoloads: PackedStringArray = []

	var project = ConfigFile.new()
	project.load("res://project.godot")
	if project.has_section("autoload"):
		return Array(project.get_section_keys("autoload")).filter(func(key): return key != "DialogueManager")

	return autoloads


## Check if a line is importing another file.
func is_import_line(text: String) -> bool:
	return text.begins_with("import ") and " as " in text


## Extract the import information from an import line
func extract_import_path_and_name(line: String) -> Dictionary:
	var found: RegExMatch = regex.IMPORT_REGEX.search(line)
	if found:
		return {
			path = found.strings[found.names.path],
			prefix = found.strings[found.names.prefix]
		}
	else:
		return {}


## Get the indent of a raw line
func get_indent(raw_line: String) -> int:
	var tabs: RegExMatch = regex.INDENT_REGEX.search(raw_line)
	if tabs:
		return tabs.get_string().length()
	else:
		return 0


## Get the type of a raw line
func get_line_type(raw_line: String) -> String:
	raw_line = raw_line.strip_edges()
	var text: String = regex.WEIGHTED_RANDOM_SIBLINGS_REGEX.sub(raw_line + " ", "").strip_edges()

	if text.begins_with("import "):
		return DMConstants.TYPE_IMPORT

	if text.begins_with("using "):
		return DMConstants.TYPE_USING

	if text.begins_with("#"):
		return DMConstants.TYPE_COMMENT

	if text.begins_with("~ "):
		return DMConstants.TYPE_TITLE

	if text.begins_with("if ") or text.begins_with("elif") or text.begins_with("else"):
		return DMConstants.TYPE_CONDITION

	if text.begins_with("while "):
		return DMConstants.TYPE_WHILE

	if text.begins_with("match "):
		return DMConstants.TYPE_MATCH

	if text.begins_with("when "):
		return DMConstants.TYPE_WHEN

	if text.begins_with("do ") or text.begins_with("do! ") or text.begins_with("set ") or text.begins_with("$> ") or text.begins_with("$>> "):
		return DMConstants.TYPE_MUTATION

	if text.begins_with("=> ") or text.begins_with("=>< "):
		return DMConstants.TYPE_GOTO

	if text.begins_with("- "):
		return DMConstants.TYPE_RESPONSE

	if raw_line.begins_with("%") and text.is_empty():
		return DMConstants.TYPE_RANDOM

	if not text.is_empty():
		return DMConstants.TYPE_DIALOGUE

	return DMConstants.TYPE_UNKNOWN


## Get the next sibling that passes a [Callable] matcher.
func get_next_matching_sibling_id(siblings: Array[DMTreeLine], from_index: int, parent: DMCompiledLine, matcher: Callable, with_empty_lines: bool = false) -> String:
	for i in range(from_index + 1, siblings.size()):
		var next_sibling: DMTreeLine = siblings[i]

		if not with_empty_lines:
			# Ignore empty lines
			if not next_sibling or next_sibling.type == DMConstants.TYPE_UNKNOWN:
				continue

		if matcher.call(next_sibling):
			return next_sibling.id

	# If no next ID can be found then check the parent for where to go next.
	if parent != null:
		return parent.id if parent.type == DMConstants.TYPE_WHILE else parent.next_id_after

	return DMConstants.ID_NULL


## Extract a static line ID from some text.
func extract_static_line_id(text: String) -> String:
		# Find a static translation key, eg. [ID:something]
	var found: RegExMatch = regex.STATIC_LINE_ID_REGEX.search(text)
	if found:
		return found.strings[found.names.id]
	else:
		return ""


## Extract a condition (or inline condition) from some text.
func extract_condition(text: String, is_wrapped: bool, index: int) -> Dictionary:
	var regex: RegEx = regex.WRAPPED_CONDITION_REGEX if is_wrapped else regex.CONDITION_REGEX
	var found: RegExMatch = regex.search(text)

	if found == null:
		return {
			index = 0,
			error = DMConstants.ERR_INCOMPLETE_EXPRESSION
		}

	var raw_condition: String = found.strings[found.names.expression]
	if raw_condition.ends_with(":"):
		raw_condition = raw_condition.substr(0, raw_condition.length() - 1)

	var expression: Array = expression_parser.tokenise(raw_condition, DMConstants.TYPE_CONDITION, index + found.get_start("expression"))

	if expression.size() == 0:
		return {
			index = index + found.get_start("expression"),
			error = DMConstants.ERR_INCOMPLETE_EXPRESSION
		}
	elif expression[0].type == DMConstants.TYPE_ERROR:
		return {
			index = expression[0].i,
			error = expression[0].value
		}
	else:
		return {
			expression = expression
		}


## Extract a mutation from some text.
func extract_mutation(text: String) -> Dictionary:
	var found: RegExMatch = regex.MUTATION_REGEX.search(text)

	if not found:
		return {
			index = 0,
			error = DMConstants.ERR_INCOMPLETE_EXPRESSION
		}

	if found.names.has("expression"):
		var expression: Array = expression_parser.tokenise(found.strings[found.names.expression], DMConstants.TYPE_MUTATION, found.get_start("expression"))
		if expression.size() == 0:
			return {
				index = found.get_start("expression"),
				error = DMConstants.ERR_INCOMPLETE_EXPRESSION
			}
		elif expression[0].type == DMConstants.TYPE_ERROR:
			return {
				index = expression[0].i,
				error = expression[0].value
			}
		else:
			return {
				expression = expression,
				is_blocking = not "!" in found.strings[found.names.keyword] and found.strings[found.names.keyword] != "$>>"
			}

	else:
		return {
			index = found.get_start(),
			error = DMConstants.ERR_INCOMPLETE_EXPRESSION
		}


## Keep track of lines referencing titles because their own next_id might not have been resolved yet.
func add_reference_to_title(title: String, line: DMCompiledLine) -> void:
	if title in [DMConstants.ID_END, DMConstants.ID_END_CONVERSATION, DMConstants.ID_NULL]: return

	if not _goto_lines.has(title):
		_goto_lines[title] = []
	_goto_lines[title].append(line)


## Parse a nested block of child lines
func parse_children(tree_line: DMTreeLine, line: DMCompiledLine) -> Array[DMCompiledLine]:
	var children = parse_line_tree(tree_line, line)
	if children.size() > 0:
		line.next_id = children.front().id
		# The last child should jump to the next line after its parent condition group
		var last_child: DMCompiledLine = children.back()
		if last_child.next_id == DMConstants.ID_NULL:
			last_child.next_id = line.next_id_after
			if last_child.siblings.size() > 0:
				for sibling in last_child.siblings:
					lines.get(sibling.id).next_id = last_child.next_id

	return children


#endregion

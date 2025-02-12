## A class for parsing a condition/mutation expression for use with the [DMCompiler].
class_name DMExpressionParser extends RefCounted


# Reference to the common [RegEx] that the parser needs.
var regex: DMCompilerRegEx = DMCompilerRegEx.new()


## Break a string down into an expression.
func tokenise(text: String, line_type: String, index: int) -> Array:
	var tokens: Array[Dictionary] = []
	var limit: int = 0
	while text.strip_edges() != "" and limit < 1000:
		limit += 1
		var found = _find_match(text)
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
			return _build_token_tree_error(DMConstants.ERR_INVALID_EXPRESSION, index)

	return _build_token_tree(tokens, line_type, "")[0]


## Extract any expressions from some text
func extract_replacements(text: String, index: int) -> Array[Dictionary]:
	var founds: Array[RegExMatch] = regex.REPLACEMENTS_REGEX.search_all(text)

	if founds == null or founds.size() == 0:
		return []

	var replacements: Array[Dictionary] = []
	for found in founds:
		var replacement: Dictionary = {}
		var value_in_text: String = found.strings[0].substr(0, found.strings[0].length() - 2).substr(2)

		# If there are closing curlie hard-up against the end of a {{...}} block then check for further
		# curlies just outside of the block.
		var text_suffix: String = text.substr(found.get_end(0))
		var expression_suffix: String = ""
		while text_suffix.begins_with("}"):
			expression_suffix += "}"
			text_suffix = text_suffix.substr(1)
		value_in_text += expression_suffix

		var expression: Array = tokenise(value_in_text, DMConstants.TYPE_DIALOGUE, index + found.get_start(1))
		if expression.size() == 0:
			replacement = {
				index = index + found.get_start(1),
				error = DMConstants.ERR_INCOMPLETE_EXPRESSION
			}
		elif expression[0].type == DMConstants.TYPE_ERROR:
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


#region Helpers


# Create a token that represents an error.
func _build_token_tree_error(error: int, index: int) -> Array:
	return [{ type = DMConstants.TOKEN_ERROR, value = error, index = index }]


# Convert a list of tokens into an abstract syntax tree.
func _build_token_tree(tokens: Array[Dictionary], line_type: String, expected_close_token: String) -> Array:
	var tree: Array[Dictionary] = []
	var limit = 0
	while tokens.size() > 0 and limit < 1000:
		limit += 1
		var token = tokens.pop_front()

		var error = _check_next_token(token, tokens, line_type, expected_close_token)
		if error != OK:
			var error_token: Dictionary = tokens[1] if tokens.size() > 1 else token
			return [_build_token_tree_error(error, error_token.index), tokens]

		match token.type:
			DMConstants.TOKEN_FUNCTION:
				var sub_tree = _build_token_tree(tokens, line_type, DMConstants.TOKEN_PARENS_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DMConstants.TOKEN_ERROR:
					return [_build_token_tree_error(sub_tree[0][0].value, sub_tree[0][0].index), tokens]

				tree.append({
					type = DMConstants.TOKEN_FUNCTION,
					# Consume the trailing "("
					function = token.value.substr(0, token.value.length() - 1),
					value = _tokens_to_list(sub_tree[0]),
					i = token.index
				})
				tokens = sub_tree[1]

			DMConstants.TOKEN_DICTIONARY_REFERENCE:
				var sub_tree = _build_token_tree(tokens, line_type, DMConstants.TOKEN_BRACKET_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DMConstants.TOKEN_ERROR:
					return [_build_token_tree_error(sub_tree[0][0].value, sub_tree[0][0].index), tokens]

				var args = _tokens_to_list(sub_tree[0])
				if args.size() != 1:
					return [_build_token_tree_error(DMConstants.ERR_INVALID_INDEX, token.index), tokens]

				tree.append({
					type = DMConstants.TOKEN_DICTIONARY_REFERENCE,
					# Consume the trailing "["
					variable = token.value.substr(0, token.value.length() - 1),
					value = args[0],
					i = token.index
				})
				tokens = sub_tree[1]

			DMConstants.TOKEN_BRACE_OPEN:
				var sub_tree = _build_token_tree(tokens, line_type, DMConstants.TOKEN_BRACE_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DMConstants.TOKEN_ERROR:
					return [_build_token_tree_error(sub_tree[0][0].value, sub_tree[0][0].index), tokens]

				var t = sub_tree[0]
				for i in range(0, t.size() - 2):
					# Convert Lua style dictionaries to string keys
					if t[i].type == DMConstants.TOKEN_VARIABLE and t[i+1].type == DMConstants.TOKEN_ASSIGNMENT:
						t[i].type = DMConstants.TOKEN_STRING
						t[i+1].type = DMConstants.TOKEN_COLON
						t[i+1].erase("value")

				tree.append({
					type = DMConstants.TOKEN_DICTIONARY,
					value = _tokens_to_dictionary(sub_tree[0]),
					i = token.index
				})

				tokens = sub_tree[1]

			DMConstants.TOKEN_BRACKET_OPEN:
				var sub_tree = _build_token_tree(tokens, line_type, DMConstants.TOKEN_BRACKET_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DMConstants.TOKEN_ERROR:
					return [_build_token_tree_error(sub_tree[0][0].value, sub_tree[0][0].index), tokens]

				var type = DMConstants.TOKEN_ARRAY
				var value = _tokens_to_list(sub_tree[0])

				# See if this is referencing a nested dictionary value
				if tree.size() > 0:
					var previous_token = tree[tree.size() - 1]
					if previous_token.type in [DMConstants.TOKEN_DICTIONARY_REFERENCE, DMConstants.TOKEN_DICTIONARY_NESTED_REFERENCE]:
						type = DMConstants.TOKEN_DICTIONARY_NESTED_REFERENCE
						value = value[0]

				tree.append({
					type = type,
					value = value,
					i = token.index
				})
				tokens = sub_tree[1]

			DMConstants.TOKEN_PARENS_OPEN:
				var sub_tree = _build_token_tree(tokens, line_type, DMConstants.TOKEN_PARENS_CLOSE)

				if sub_tree[0].size() > 0 and sub_tree[0][0].type == DMConstants.TOKEN_ERROR:
					return [_build_token_tree_error(sub_tree[0][0].value, sub_tree[0][0].index), tokens]

				tree.append({
					type = DMConstants.TOKEN_GROUP,
					value = sub_tree[0],
					i = token.index
				})
				tokens = sub_tree[1]

			DMConstants.TOKEN_PARENS_CLOSE, \
			DMConstants.TOKEN_BRACE_CLOSE, \
			DMConstants.TOKEN_BRACKET_CLOSE:
				if token.type != expected_close_token:
					return [_build_token_tree_error(DMConstants.ERR_UNEXPECTED_CLOSING_BRACKET, token.index), tokens]

				tree.append({
					type = token.type,
					i = token.index
				})

				return [tree, tokens]

			DMConstants.TOKEN_NOT:
				# Double nots negate each other
				if tokens.size() > 0 and tokens.front().type == DMConstants.TOKEN_NOT:
					tokens.pop_front()
				else:
					tree.append({
						type = token.type,
						i = token.index
					})

			DMConstants.TOKEN_COMMA, \
			DMConstants.TOKEN_COLON, \
			DMConstants.TOKEN_DOT:
				tree.append({
					type = token.type,
						i = token.index
				})

			DMConstants.TOKEN_COMPARISON, \
			DMConstants.TOKEN_ASSIGNMENT, \
			DMConstants.TOKEN_OPERATOR, \
			DMConstants.TOKEN_AND_OR, \
			DMConstants.TOKEN_VARIABLE:
				var value = token.value.strip_edges()
				if value == "&&":
					value = "and"
				elif value == "||":
					value = "or"
				tree.append({
					type = token.type,
					value = value,
						i = token.index
				})

			DMConstants.TOKEN_STRING:
				if token.value.begins_with("&"):
					tree.append({
						type = token.type,
						value = StringName(token.value.substr(2, token.value.length() - 3)),
						i = token.index
					})
				else:
					tree.append({
						type = token.type,
						value = token.value.substr(1, token.value.length() - 2),
						i = token.index
					})

			DMConstants.TOKEN_CONDITION:
				return [_build_token_tree_error(DMConstants.ERR_UNEXPECTED_CONDITION, token.index), token]

			DMConstants.TOKEN_BOOL:
				tree.append({
					type = token.type,
					value = token.value.to_lower() == "true",
					i = token.index
				})

			DMConstants.TOKEN_NUMBER:
				var value = token.value.to_float() if "." in token.value else token.value.to_int()
				# If previous token is a number and this one is a negative number then
				# inject a minus operator token in between them.
				if tree.size() > 0 and token.value.begins_with("-") and tree[tree.size() - 1].type == DMConstants.TOKEN_NUMBER:
					tree.append(({
						type = DMConstants.TOKEN_OPERATOR,
						value = "-",
						i = token.index
					}))
					tree.append({
						type = token.type,
						value = -1 * value,
						i = token.index
					})
				else:
					tree.append({
						type = token.type,
						value = value,
						i = token.index
					})

	if expected_close_token != "":
		var index: int = tokens[0].index if tokens.size() > 0 else 0
		return [_build_token_tree_error(DMConstants.ERR_MISSING_CLOSING_BRACKET, index), tokens]

	return [tree, tokens]


# Check the next token to see if it is valid to follow this one.
func _check_next_token(token: Dictionary, next_tokens: Array[Dictionary], line_type: String, expected_close_token: String) -> Error:
	var next_token: Dictionary = { type = null }
	if next_tokens.size() > 0:
		next_token = next_tokens.front()

	# Guard for assigning in a condition. If the assignment token isn't inside a Lua dictionary
	# then it's an unexpected assignment in a condition line.
	if token.type == DMConstants.TOKEN_ASSIGNMENT and line_type == DMConstants.TYPE_CONDITION and not next_tokens.any(func(t): return t.type == expected_close_token):
		return DMConstants.ERR_UNEXPECTED_ASSIGNMENT

	# Special case for a negative number after this one
	if token.type == DMConstants.TOKEN_NUMBER and next_token.type == DMConstants.TOKEN_NUMBER and next_token.value.begins_with("-"):
		return OK

	var expected_token_types = []
	var unexpected_token_types = []
	match token.type:
		DMConstants.TOKEN_FUNCTION, \
		DMConstants.TOKEN_PARENS_OPEN:
			unexpected_token_types = [
				null,
				DMConstants.TOKEN_COMMA,
				DMConstants.TOKEN_COLON,
				DMConstants.TOKEN_COMPARISON,
				DMConstants.TOKEN_ASSIGNMENT,
				DMConstants.TOKEN_OPERATOR,
				DMConstants.TOKEN_AND_OR,
				DMConstants.TOKEN_DOT
			]

		DMConstants.TOKEN_BRACKET_CLOSE:
			unexpected_token_types = [
				DMConstants.TOKEN_NOT,
				DMConstants.TOKEN_BOOL,
				DMConstants.TOKEN_STRING,
				DMConstants.TOKEN_NUMBER,
				DMConstants.TOKEN_VARIABLE
			]

		DMConstants.TOKEN_BRACE_OPEN:
			expected_token_types = [
				DMConstants.TOKEN_STRING,
				DMConstants.TOKEN_VARIABLE,
				DMConstants.TOKEN_NUMBER,
				DMConstants.TOKEN_BRACE_CLOSE
			]

		DMConstants.TOKEN_PARENS_CLOSE, \
		DMConstants.TOKEN_BRACE_CLOSE:
			unexpected_token_types = [
				DMConstants.TOKEN_NOT,
				DMConstants.TOKEN_ASSIGNMENT,
				DMConstants.TOKEN_BOOL,
				DMConstants.TOKEN_STRING,
				DMConstants.TOKEN_NUMBER,
				DMConstants.TOKEN_VARIABLE
			]

		DMConstants.TOKEN_COMPARISON, \
		DMConstants.TOKEN_OPERATOR, \
		DMConstants.TOKEN_COMMA, \
		DMConstants.TOKEN_DOT, \
		DMConstants.TOKEN_NOT, \
		DMConstants.TOKEN_AND_OR, \
		DMConstants.TOKEN_DICTIONARY_REFERENCE:
			unexpected_token_types = [
				null,
				DMConstants.TOKEN_COMMA,
				DMConstants.TOKEN_COLON,
				DMConstants.TOKEN_COMPARISON,
				DMConstants.TOKEN_ASSIGNMENT,
				DMConstants.TOKEN_OPERATOR,
				DMConstants.TOKEN_AND_OR,
				DMConstants.TOKEN_PARENS_CLOSE,
				DMConstants.TOKEN_BRACE_CLOSE,
				DMConstants.TOKEN_BRACKET_CLOSE,
				DMConstants.TOKEN_DOT
			]

		DMConstants.TOKEN_COLON:
			unexpected_token_types = [
				DMConstants.TOKEN_COMMA,
				DMConstants.TOKEN_COLON,
				DMConstants.TOKEN_COMPARISON,
				DMConstants.TOKEN_ASSIGNMENT,
				DMConstants.TOKEN_OPERATOR,
				DMConstants.TOKEN_AND_OR,
				DMConstants.TOKEN_PARENS_CLOSE,
				DMConstants.TOKEN_BRACE_CLOSE,
				DMConstants.TOKEN_BRACKET_CLOSE,
				DMConstants.TOKEN_DOT
			]

		DMConstants.TOKEN_BOOL, \
		DMConstants.TOKEN_STRING, \
		DMConstants.TOKEN_NUMBER:
			unexpected_token_types = [
				DMConstants.TOKEN_NOT,
				DMConstants.TOKEN_ASSIGNMENT,
				DMConstants.TOKEN_BOOL,
				DMConstants.TOKEN_STRING,
				DMConstants.TOKEN_NUMBER,
				DMConstants.TOKEN_VARIABLE,
				DMConstants.TOKEN_FUNCTION,
				DMConstants.TOKEN_PARENS_OPEN,
				DMConstants.TOKEN_BRACE_OPEN,
				DMConstants.TOKEN_BRACKET_OPEN
			]

		DMConstants.TOKEN_VARIABLE:
			unexpected_token_types = [
				DMConstants.TOKEN_NOT,
				DMConstants.TOKEN_BOOL,
				DMConstants.TOKEN_STRING,
				DMConstants.TOKEN_NUMBER,
				DMConstants.TOKEN_VARIABLE,
				DMConstants.TOKEN_FUNCTION,
				DMConstants.TOKEN_PARENS_OPEN,
				DMConstants.TOKEN_BRACE_OPEN,
				DMConstants.TOKEN_BRACKET_OPEN
			]

	if (expected_token_types.size() > 0 and not next_token.type in expected_token_types or unexpected_token_types.size() > 0 and next_token.type in unexpected_token_types):
		match next_token.type:
			null:
				return DMConstants.ERR_UNEXPECTED_END_OF_EXPRESSION

			DMConstants.TOKEN_FUNCTION:
				return DMConstants.ERR_UNEXPECTED_FUNCTION

			DMConstants.TOKEN_PARENS_OPEN, \
			DMConstants.TOKEN_PARENS_CLOSE:
				return DMConstants.ERR_UNEXPECTED_BRACKET

			DMConstants.TOKEN_COMPARISON, \
			DMConstants.TOKEN_ASSIGNMENT, \
			DMConstants.TOKEN_OPERATOR, \
			DMConstants.TOKEN_NOT, \
			DMConstants.TOKEN_AND_OR:
				return DMConstants.ERR_UNEXPECTED_OPERATOR

			DMConstants.TOKEN_COMMA:
				return DMConstants.ERR_UNEXPECTED_COMMA
			DMConstants.TOKEN_COLON:
				return DMConstants.ERR_UNEXPECTED_COLON
			DMConstants.TOKEN_DOT:
				return DMConstants.ERR_UNEXPECTED_DOT

			DMConstants.TOKEN_BOOL:
				return DMConstants.ERR_UNEXPECTED_BOOLEAN
			DMConstants.TOKEN_STRING:
				return DMConstants.ERR_UNEXPECTED_STRING
			DMConstants.TOKEN_NUMBER:
				return DMConstants.ERR_UNEXPECTED_NUMBER
			DMConstants.TOKEN_VARIABLE:
				return DMConstants.ERR_UNEXPECTED_VARIABLE

		return DMConstants.ERR_INVALID_EXPRESSION

	return OK


# Convert a series of comma separated tokens to an [Array].
func _tokens_to_list(tokens: Array[Dictionary]) -> Array[Array]:
	var list: Array[Array] = []
	var current_item: Array[Dictionary] = []
	for token in tokens:
		if token.type == DMConstants.TOKEN_COMMA:
			list.append(current_item)
			current_item = []
		else:
			current_item.append(token)

	if current_item.size() > 0:
		list.append(current_item)

	return list


# Convert a series of key/value tokens into a [Dictionary]
func _tokens_to_dictionary(tokens: Array[Dictionary]) -> Dictionary:
	var dictionary = {}
	for i in range(0, tokens.size()):
		if tokens[i].type == DMConstants.TOKEN_COLON:
			if tokens.size() == i + 2:
				dictionary[tokens[i - 1]] = tokens[i + 1]
			else:
				dictionary[tokens[i - 1]] = { type = DMConstants.TOKEN_GROUP, value = tokens.slice(i + 1), i = tokens[0].i }

	return dictionary


# Work out what the next token is from a string.
func _find_match(input: String) -> Dictionary:
	for key in regex.TOKEN_DEFINITIONS.keys():
		var regex = regex.TOKEN_DEFINITIONS.get(key)
		var found = regex.search(input)
		if found:
			return {
				type = key,
				remaining_text = input.substr(found.strings[0].length()),
				value = found.strings[0]
			}

	return {}


#endregion

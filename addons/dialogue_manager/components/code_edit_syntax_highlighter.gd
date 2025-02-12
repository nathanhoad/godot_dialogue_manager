@tool
class_name DMSyntaxHighlighter extends SyntaxHighlighter


var regex: DMCompilerRegEx = DMCompilerRegEx.new()
var compilation: DMCompilation = DMCompilation.new()
var expression_parser = DMExpressionParser.new()

var cache: Dictionary = {}


func _clear_highlighting_cache() -> void:
	cache.clear()


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var colors: Dictionary = {}
	var text_edit: TextEdit = get_text_edit()
	var text: String = text_edit.get_line(line)

	# Prevent an error from popping up while developing
	if not is_instance_valid(text_edit) or text_edit.theme_overrides.is_empty():
		return colors

	# Disable this, as well as the line at the bottom of this function to remove the cache.
	if text in cache:
		return cache[text]

	var theme: Dictionary = text_edit.theme_overrides

	var index: int = 0

	match DMCompiler.get_line_type(text):
		DMConstants.TYPE_COMMENT:
			colors[index] = { color = theme.comments_color }

		DMConstants.TYPE_TITLE:
			colors[index] = { color = theme.titles_color }

		DMConstants.TYPE_CONDITION, DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH, DMConstants.TYPE_WHEN:
			colors[0] = { color = theme.conditions_color }
			index = text.find(" ")
			if index > -1:
				var expression: Array = expression_parser.tokenise(text.substr(index), DMConstants.TYPE_CONDITION, 0)
				if expression.size() == 0 or expression[0].type == DMConstants.TYPE_ERROR:
					colors[index] = { color = theme.critical_color }
				else:
					_highlight_expression(expression, colors, index)

		DMConstants.TYPE_MUTATION:
			colors[0] = { color = theme.mutations_color }
			index = text.find(" ")
			var expression: Array = expression_parser.tokenise(text.substr(index), DMConstants.TYPE_MUTATION, 0)
			if expression.size() == 0 or expression[0].type == DMConstants.TYPE_ERROR:
				colors[index] = { color = theme.critical_color }
			else:
				_highlight_expression(expression, colors, index)

		DMConstants.TYPE_GOTO:
			if text.strip_edges().begins_with("%"):
				colors[index] = { color = theme.symbols_color }
				index = text.find(" ")
			_highlight_goto(text, colors, index)

		DMConstants.TYPE_RANDOM:
			colors[index] = { color = theme.symbols_color }

		DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RESPONSE:
			if text.strip_edges().begins_with("%"):
				colors[index] = { color = theme.symbols_color }
				index = text.find(" ")
			colors[index] = { color = theme.text_color }

			var dialogue_text: String = text.substr(index, text.find("=>"))

			# Interpolation
			var replacements: Array[RegExMatch] = regex.REPLACEMENTS_REGEX.search_all(dialogue_text)
			for replacement: RegExMatch in replacements:
				var expression_text: String = replacement.get_string().substr(0, replacement.get_string().length() - 2).substr(2)
				var expression: Array = expression_parser.tokenise(expression_text, DMConstants.TYPE_MUTATION, replacement.get_start())
				var expression_index: int = index + replacement.get_start()
				colors[expression_index] = { color = theme.symbols_color }
				if expression.size() == 0 or expression[0].type == DMConstants.TYPE_ERROR:
					colors[expression_index] = { color = theme.critical_color }
				else:
					_highlight_expression(expression, colors, index + 2)
				colors[expression_index + expression_text.length() + 2] = { color = theme.symbols_color }
				colors[expression_index + expression_text.length() + 4] = { color = theme.text_color }
			# Tags (and inline mutations)
			var resolved_line_data: DMResolvedLineData = DMResolvedLineData.new("")
			var bbcodes: Array[Dictionary] = resolved_line_data.find_bbcode_positions_in_string(dialogue_text, true, true)
			for bbcode: Dictionary in bbcodes:
				var tag: String = bbcode.code
				var code: String = bbcode.raw_args
				if code.begins_with("["):
					colors[bbcode.start] = { color = theme.symbols_color }
					colors[bbcode.start + 2] = { color = theme.text_color }
					var pipe_cursor: int = code.find("|")
					while pipe_cursor > -1:
						colors[bbcode.start + pipe_cursor + 1] = { color = theme.symbols_color }
						colors[bbcode.start + pipe_cursor + 2] = { color = theme.text_color }
						pipe_cursor = code.find("|", pipe_cursor + 1)
					colors[bbcode.end - 1] = { color = theme.symbols_color }
					colors[bbcode.end + 1] = { color = theme.text_color }
				else:
					colors[bbcode.start] = { color = theme.symbols_color }
					if tag.begins_with("do") or tag.begins_with("set") or tag.begins_with("if"):
						if tag.begins_with("if"):
							colors[bbcode.start + 1] = { color = theme.conditions_color }
						else:
							colors[bbcode.start + 1] = { color = theme.mutations_color }
						var expression: Array = expression_parser.tokenise(code, DMConstants.TYPE_MUTATION, bbcode.start + bbcode.code.length())
						if expression.size() == 0 or expression[0].type == DMConstants.TYPE_ERROR:
							colors[bbcode.start + tag.length() + 1] = { color = theme.critical_color }
						else:
							_highlight_expression(expression, colors, index + 2)
					# else and closing if have no expression
					elif tag.begins_with("else") or tag.begins_with("/if"):
						colors[bbcode.start + 1] = { color = theme.conditions_color }
					colors[bbcode.end] = { color = theme.symbols_color }
					colors[bbcode.end + 1] = { color = theme.text_color }
			# Jumps
			if "=> " in text or "=>< " in text:
				_highlight_goto(text, colors, index)

	# Order the dictionary keys to prevent CodeEdit from having issues
	var ordered_colors: Dictionary = {}
	var ordered_keys: Array = colors.keys()
	ordered_keys.sort()
	for key_index: int in ordered_keys:
		ordered_colors[key_index] = colors[key_index]

	cache[text] = ordered_colors
	return ordered_colors


func _highlight_expression(tokens: Array, colors: Dictionary, index: int) -> int:
	var theme: Dictionary = get_text_edit().theme_overrides
	var last_index: int = index
	for token: Dictionary in tokens:
		last_index = token.i
		match token.type:
			DMConstants.TOKEN_CONDITION, DMConstants.TOKEN_AND_OR:
				colors[index + token.i] = { color = theme.conditions_color }

			DMConstants.TOKEN_VARIABLE:
				if token.value in ["true", "false"]:
					colors[index + token.i] = { color = theme.conditions_color }
				else:
					colors[index + token.i] = { color = theme.members_color }

			DMConstants.TOKEN_OPERATOR, DMConstants.TOKEN_COLON, DMConstants.TOKEN_COMMA, DMConstants.TOKEN_NUMBER, DMConstants.TOKEN_ASSIGNMENT:
				colors[index + token.i] = { color = theme.symbols_color }

			DMConstants.TOKEN_STRING:
				colors[index + token.i] = { color = theme.strings_color }

			DMConstants.TOKEN_FUNCTION:
				colors[index + token.i] = { color = theme.mutations_color }
				colors[index + token.i + token.function.length()] = { color = theme.symbols_color }
				for parameter: Array in token.value:
					last_index = _highlight_expression(parameter, colors, index)
			DMConstants.TOKEN_PARENS_CLOSE:
				colors[index + token.i] = { color = theme.symbols_color }

			DMConstants.TOKEN_DICTIONARY_REFERENCE:
				colors[index + token.i] = { color = theme.members_color }
				colors[index + token.i + token.variable.length()] = { color = theme.symbols_color }
				last_index = _highlight_expression(token.value, colors, index)
			DMConstants.TOKEN_ARRAY:
				colors[index + token.i] = { color = theme.symbols_color }
				for item: Array in token.value:
					last_index = _highlight_expression(item, colors, index)
			DMConstants.TOKEN_BRACKET_CLOSE:
				colors[index + token.i] = { color = theme.symbols_color }

			DMConstants.TOKEN_DICTIONARY:
				colors[index + token.i] = { color = theme.symbols_color }
				last_index = _highlight_expression(token.value.keys() + token.value.values(), colors, index)
			DMConstants.TOKEN_BRACE_CLOSE:
				colors[index + token.i] = { color = theme.symbols_color }
				last_index += 1

			DMConstants.TOKEN_GROUP:
				last_index = _highlight_expression(token.value, colors, index)

	return last_index


func _highlight_goto(text: String, colors: Dictionary, index: int) -> int:
	var theme: Dictionary = get_text_edit().theme_overrides
	var goto_data: DMResolvedGotoData = DMResolvedGotoData.new(text, {})
	colors[goto_data.index] = { color = theme.jumps_color }
	if "{{" in text:
		index = text.find("{{", goto_data.index)
		var last_index: int = 0
		if goto_data.error:
			colors[index + 2] = { color = theme.critical_color }
		else:
			last_index = _highlight_expression(goto_data.expression, colors, index)
		index = text.find("}}", index + last_index)
		colors[index] = { color = theme.jumps_color }

	return index

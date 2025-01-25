## Data associated with a dialogue jump/goto line.
class_name DMResolvedGotoData extends RefCounted


## The title that was specified
var title: String = ""
## The target line's ID
var next_id: String = ""
## An expression to determine the target line at runtime.
var expression: Array[Dictionary] = []
## The given line text with the jump syntax removed.
var text_without_goto: String = ""
## Whether this is a jump-and-return style jump.
var is_snippet: bool = false
## A parse error if there was one.
var error: int

# An instance of the compiler [RegEx] list.
var regex: DMCompilerRegEx = DMCompilerRegEx.new()


func _init(text: String, titles: Dictionary) -> void:
	if not "=> " in text and not "=>< " in text: return

	if "=> " in text:
		text_without_goto = text.substr(0, text.find("=> ")).strip_edges()
	elif "=>< " in text:
		is_snippet = true
		text_without_goto = text.substr(0, text.find("=>< ")).strip_edges()

	var found: RegExMatch = regex.GOTO_REGEX.search(text)
	if found == null:
		return

	title = found.strings[found.names.goto].strip_edges()

	if title == "":
		error = DMConstants.ERR_UNKNOWN_TITLE
		return

	# "=> END!" means end the conversation, ignoring any "=><" chains.
	if title == "END!":
		next_id = DMConstants.ID_END_CONVERSATION

	# "=> END" means end the current title (and go back to the previous one if there is one
	# in the stack)
	elif title == "END":
		next_id = DMConstants.ID_END

	elif titles.has(title):
		next_id = titles.get(title)
	elif title.begins_with("{{"):
		var expression_parser: DMExpressionParser = DMExpressionParser.new()
		var title_expression: Array[Dictionary] = expression_parser.extract_replacements(title, 0)
		if title_expression[0].has("error"):
			error = title_expression[0].eror
		else:
			expression = title_expression[0].expression
	else:
		next_id = title
		error = DMConstants.ERR_UNKNOWN_TITLE


func _to_string() -> String:
	return "%s =>%s %s (%s)" % [text_without_goto, "<" if is_snippet else "", title, next_id]

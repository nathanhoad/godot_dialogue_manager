## Data associated with a dialogue jump/goto line.
class_name DMResolvedGotoData extends RefCounted


## The label that was specified
var label: String = ""
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
## The index in the string where
var index: int = 0

# An instance of the compiler [RegEx] list.
var regex: DMCompilerRegEx = DMCompilerRegEx.new()


func _init(text: String, labels: Dictionary) -> void:
	if not "=> " in text and not "=>< " in text: return

	if "=> " in text:
		text_without_goto = text.substr(0, text.find("=> ")).strip_edges()
	elif "=>< " in text:
		is_snippet = true
		text_without_goto = text.substr(0, text.find("=>< ")).strip_edges()

	var found: RegExMatch = regex.GOTO_REGEX.search(text)
	if found == null:
		return

	label = found.strings[found.names.goto].strip_edges()
	index = found.get_start(0)

	if label == "":
		error = DMConstants.ERR_UNKNOWN_LABEL
		return

	# "=> END!" means end the conversation, ignoring any "=><" chains.
	if label == "END!":
		next_id = DMConstants.ID_END_CONVERSATION

	# "=> END" means end the current label (and go back to the previous one if there is one
	# in the stack)
	elif label == "END":
		next_id = DMConstants.ID_END

	elif labels.has(label):
		next_id = labels.get(label)
	elif label.begins_with("{{"):
		var expression_parser: DMExpressionParser = DMExpressionParser.new()
		var label_expression: Array[Dictionary] = expression_parser.extract_replacements(label, 0)
		if label_expression.size() == 0:
			error = DMConstants.ERR_INCOMPLETE_EXPRESSION
		elif label_expression[0].has("error"):
			error = label_expression[0].error
		else:
			expression = label_expression[0].expression
	else:
		next_id = label
		error = DMConstants.ERR_UNKNOWN_LABEL


func _to_string() -> String:
	return "%s =>%s %s (%s)" % [text_without_goto, "<" if is_snippet else "", label, next_id]

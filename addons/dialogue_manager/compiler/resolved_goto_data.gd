## Data associated with a dialogue jump/goto line.
class_name DMResolvedGotoData extends RefCounted


## The cue that was specified
var cue: String = ""
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


func _init(text: String, cues: Dictionary) -> void:
	if not "=> " in text and not "=>< " in text: return

	if "=> " in text:
		text_without_goto = text.substr(0, text.find("=> ")).strip_edges()
	elif "=>< " in text:
		is_snippet = true
		text_without_goto = text.substr(0, text.find("=>< ")).strip_edges()

	var found: RegExMatch = regex.GOTO_REGEX.search(text)
	if found == null:
		return

	cue = found.strings[found.names.goto].strip_edges()
	index = found.get_start(0)

	if cue == "":
		error = DMConstants.ERR_UNKNOWN_CUE
		return

	# "=> END!" means end the conversation, ignoring any "=><" chains.
	if cue == "END!":
		next_id = DMConstants.ID_END_CONVERSATION

	# "=> END" means end the current cue (and go back to the previous one if there is one
	# in the stack)
	elif cue == "END":
		next_id = DMConstants.ID_END

	elif cues.has(cue):
		next_id = cues.get(cue)
	elif cue.begins_with("{{"):
		var expression_parser: DMExpressionParser = DMExpressionParser.new()
		var cue_expression: Array[Dictionary] = expression_parser.extract_replacements(cue, 0)
		if cue_expression.size() == 0:
			error = DMConstants.ERR_INCOMPLETE_EXPRESSION
		elif cue_expression[0].has("error"):
			error = cue_expression[0].error
		else:
			expression = cue_expression[0].expression
	else:
		next_id = cue
		error = DMConstants.ERR_UNKNOWN_CUE


func _to_string() -> String:
	return "%s =>%s %s (%s)" % [text_without_goto, "<" if is_snippet else "", cue, next_id]

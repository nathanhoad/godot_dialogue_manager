## A collection of [RegEx] for use by the [DMCompiler].
class_name DMCompilerRegEx extends RefCounted


var IMPORT_REGEX: RegEx = RegEx.create_from_string("import \"(?<path>[^\"]+)\" as (?<prefix>[a-zA-Z_\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}][a-zA-Z_0-9\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}]+)")
var USING_REGEX: RegEx = RegEx.create_from_string("^using (?<state>.*)$")
var INDENT_REGEX: RegEx = RegEx.create_from_string("^\\t+")
var VALID_TITLE_REGEX: RegEx = RegEx.create_from_string("^[a-zA-Z_0-9\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}][a-zA-Z_0-9\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}]*$")
var BEGINS_WITH_NUMBER_REGEX: RegEx = RegEx.create_from_string("^\\d")
var CONDITION_REGEX: RegEx = RegEx.create_from_string("(if|elif|while|else if|match|when) (?<expression>.*)\\:?")
var WRAPPED_CONDITION_REGEX: RegEx = RegEx.create_from_string("\\[if (?<expression>.*)\\]")
var MUTATION_REGEX: RegEx = RegEx.create_from_string("(?<keyword>do|do!|set) (?<expression>.*)")
var STATIC_LINE_ID_REGEX: RegEx = RegEx.create_from_string("\\[ID:(?<id>.*?)\\]")
var WEIGHTED_RANDOM_SIBLINGS_REGEX: RegEx = RegEx.create_from_string("^\\%(?<weight>[\\d.]+)?( \\[if (?<condition>.+?)\\])? ")
var GOTO_REGEX: RegEx = RegEx.create_from_string("=><? (?<goto>.*)")

var INLINE_RANDOM_REGEX: RegEx = RegEx.create_from_string("\\[\\[(?<options>.*?)\\]\\]")
var INLINE_CONDITIONALS_REGEX: RegEx = RegEx.create_from_string("\\[if (?<condition>.+?)\\](?<body>.*?)\\[\\/if\\]")

var TAGS_REGEX: RegEx = RegEx.create_from_string("\\[#(?<tags>.*?)\\]")

var REPLACEMENTS_REGEX: RegEx = RegEx.create_from_string("{{(.*?)}}")

var ALPHA_NUMERIC: RegEx = RegEx.create_from_string("[^a-zA-Z0-9\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}]+")

var TOKEN_DEFINITIONS: Dictionary = {
	DMConstants.TOKEN_FUNCTION: RegEx.create_from_string("^[a-zA-Z_\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}][a-zA-Z_0-9\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}]*\\("),
	DMConstants.TOKEN_DICTIONARY_REFERENCE: RegEx.create_from_string("^[a-zA-Z_\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}][a-zA-Z_0-9\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}]*\\["),
	DMConstants.TOKEN_PARENS_OPEN: RegEx.create_from_string("^\\("),
	DMConstants.TOKEN_PARENS_CLOSE: RegEx.create_from_string("^\\)"),
	DMConstants.TOKEN_BRACKET_OPEN: RegEx.create_from_string("^\\["),
	DMConstants.TOKEN_BRACKET_CLOSE: RegEx.create_from_string("^\\]"),
	DMConstants.TOKEN_BRACE_OPEN: RegEx.create_from_string("^\\{"),
	DMConstants.TOKEN_BRACE_CLOSE: RegEx.create_from_string("^\\}"),
	DMConstants.TOKEN_COLON: RegEx.create_from_string("^:"),
	DMConstants.TOKEN_COMPARISON: RegEx.create_from_string("^(==|<=|>=|<|>|!=|in )"),
	DMConstants.TOKEN_ASSIGNMENT: RegEx.create_from_string("^(\\+=|\\-=|\\*=|/=|=)"),
	DMConstants.TOKEN_NUMBER: RegEx.create_from_string("^\\-?\\d+(\\.\\d+)?"),
	DMConstants.TOKEN_OPERATOR: RegEx.create_from_string("^(\\+|\\-|\\*|/|%)"),
	DMConstants.TOKEN_COMMA: RegEx.create_from_string("^,"),
	DMConstants.TOKEN_DOT: RegEx.create_from_string("^\\."),
	DMConstants.TOKEN_STRING: RegEx.create_from_string("^&?(\".*?\"|\'.*?\')"),
	DMConstants.TOKEN_NOT: RegEx.create_from_string("^(not( |$)|!)"),
	DMConstants.TOKEN_AND_OR: RegEx.create_from_string("^(and|or|&&|\\|\\|)( |$)"),
	DMConstants.TOKEN_VARIABLE: RegEx.create_from_string("^[a-zA-Z_\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}][a-zA-Z_0-9\\p{Emoji_Presentation}\\p{Han}\\p{Katakana}\\p{Hiragana}\\p{Cyrillic}]*"),
	DMConstants.TOKEN_COMMENT: RegEx.create_from_string("^#.*"),
	DMConstants.TOKEN_CONDITION: RegEx.create_from_string("^(if|elif|else)"),
	DMConstants.TOKEN_BOOL: RegEx.create_from_string("^(true|false)")
}

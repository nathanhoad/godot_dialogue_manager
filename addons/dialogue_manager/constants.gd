extends Node


const USER_CONFIG_PATH = "user://dialogue_manager_user_config.json"
const CACHE_PATH = "user://dialogue_manager_cache.json"

# Token types

const TOKEN_FUNCTION = "function"
const TOKEN_DICTIONARY_REFERENCE = "dictionary_reference"
const TOKEN_DICTIONARY_NESTED_REFERENCE = "dictionary_nested_reference"
const TOKEN_GROUP = "group"
const TOKEN_ARRAY = "array"
const TOKEN_DICTIONARY = "dictionary"
const TOKEN_PARENS_OPEN = "parens_open"
const TOKEN_PARENS_CLOSE = "parens_close"
const TOKEN_BRACKET_OPEN = "bracket_open"
const TOKEN_BRACKET_CLOSE = "bracket_close"
const TOKEN_BRACE_OPEN = "brace_open"
const TOKEN_BRACE_CLOSE = "brace_close"
const TOKEN_COLON = "colon"
const TOKEN_COMPARISON = "comparison"
const TOKEN_ASSIGNMENT = "assignment"
const TOKEN_OPERATOR = "operator"
const TOKEN_COMMA = "comma"
const TOKEN_DOT = "dot"
const TOKEN_BOOL = "bool"
const TOKEN_NOT = "not"
const TOKEN_AND_OR = "and_or"
const TOKEN_STRING = "string"
const TOKEN_NUMBER = "number"
const TOKEN_VARIABLE = "variable"
const TOKEN_COMMENT = "comment"

const TOKEN_ERROR = "error"

# Line types

const TYPE_UNKNOWN = "unknown"
const TYPE_RESPONSE = "response"
const TYPE_TITLE = "title"
const TYPE_CONDITION = "condition"
const TYPE_MUTATION = "mutation"
const TYPE_GOTO = "goto"
const TYPE_DIALOGUE = "dialogue"
const TYPE_ERROR = "error"

const TYPE_ELSE = "else"

# Line IDs

const ID_NULL = ""
const ID_ERROR = "error"
const ID_ERROR_INVALID_TITLE = "invalid title"
const ID_ERROR_TITLE_HAS_NO_BODY = "title has no body"
const ID_END = "end"
const ID_END_CONVERSATION = "end!"

# Errors

const ERR_ERRORS_IN_IMPORTED_FILE = 100
const ERR_FILE_ALREADY_IMPORTED = 101
const ERR_DUPLICATE_IMPORT_NAME = 102
const ERR_EMPTY_TITLE = 103
const ERR_DUPLICATE_TITLE = 104
const ERR_NESTED_TITLE = 105
const ERR_TITLE_INVALID_CHARACTERS = 106
const ERR_UNKNOWN_TITLE = 107
const ERR_INVALID_TITLE_REFERENCE = 108
const ERR_TITLE_REFERENCE_HAS_NO_CONTENT = 109
const ERR_INVALID_EXPRESSION = 110
const ERR_INVALID_EXPRESSION_IN_CHARACTER_NAME = 111
const ERR_DUPLICATE_ID = 112
const ERR_MISSING_ID = 113
const ERR_INVALID_INDENTATION = 114
const ERR_INVALID_CONDITION_INDENTATION = 115
const ERR_INCOMPLETE_EXPRESSION = 116
const ERR_INVALID_EXPRESSION_FOR_VALUE = 117
const ERR_UNKNOWN_LINE_SYNTAX = 118
const ERR_TITLE_BEGINS_WITH_NUMBER = 119
const ERR_UNEXPECTED_END_OF_EXPRESSION = 120
const ERR_UNEXPECTED_FUNCTION = 121
const ERR_UNEXPECTED_BRACKET = 122
const ERR_UNEXPECTED_CLOSING_BRACKET = 123
const ERR_MISSING_CLOSING_BRACKET = 124
const ERR_UNEXPECTED_OPERATOR = 125
const ERR_UNEXPECTED_COMMA = 126
const ERR_UNEXPECTED_COLON = 127
const ERR_UNEXPECTED_DOT = 128
const ERR_UNEXPECTED_BOOLEAN = 129
const ERR_UNEXPECTED_STRING = 130
const ERR_UNEXPECTED_NUMBER = 131
const ERR_UNEXPECTED_VARIABLE = 132
const ERR_INVALID_INDEX = 133
const ERR_UNEXPECTED_ASSIGNMENT = 134


## Get the error message
static func get_error_message(error: int) -> String:
	match error:
		ERR_ERRORS_IN_IMPORTED_FILE:
			return "There are errors in this imported file."
		ERR_FILE_ALREADY_IMPORTED:
			return "File already imported."
		ERR_DUPLICATE_IMPORT_NAME:
			return "Duplicate import name."
		ERR_EMPTY_TITLE:
			return "Titles cannot be empty."
		ERR_DUPLICATE_TITLE:
			return "There is already a title with that name."
		ERR_NESTED_TITLE:
			return "Titles cannot be nested."
		ERR_TITLE_INVALID_CHARACTERS:
			return "Titles can only contain alphanumeric characters and numbers."
		ERR_TITLE_BEGINS_WITH_NUMBER:
			return "Titles cannot begin with a number."
		ERR_UNKNOWN_TITLE:
			return "Unknown title."
		ERR_INVALID_TITLE_REFERENCE:
			return "This jump is pointing to an invalid title."
		ERR_TITLE_REFERENCE_HAS_NO_CONTENT:
			return "That title has no content. Maybe change this to a \"=> END\"."
		ERR_INVALID_EXPRESSION:
			return "Expression is invalid."
		ERR_INVALID_EXPRESSION_IN_CHARACTER_NAME:
			return "The expression used for a character name is invalid."
		ERR_DUPLICATE_ID:
			return "This ID is already on another line."
		ERR_MISSING_ID:
			return "This line is missing an ID."
		ERR_INVALID_INDENTATION:
			return "Invalid indentation."
		ERR_INVALID_CONDITION_INDENTATION:
			return "A condition line needs an indented line below it."
		ERR_INCOMPLETE_EXPRESSION:
			return "Incomplate expression."
		ERR_INVALID_EXPRESSION_FOR_VALUE:
			return "Invalid expression for value."
		ERR_FILE_NOT_FOUND:
			return "File not found."
		ERR_UNEXPECTED_END_OF_EXPRESSION:
			return "Unexpected end of expression."
		ERR_UNEXPECTED_FUNCTION:
			return "Unexpected function."
		ERR_UNEXPECTED_BRACKET:
			return "Unexpected bracket."
		ERR_UNEXPECTED_CLOSING_BRACKET:
			return "Unexpected closing bracket."
		ERR_MISSING_CLOSING_BRACKET:
			return "Missing closing bracket."
		ERR_UNEXPECTED_OPERATOR:
			return "Unexpected operator."
		ERR_UNEXPECTED_COMMA:
			return "Unexpected comma."
		ERR_UNEXPECTED_COLON:
			return "Unexpected colon."
		ERR_UNEXPECTED_DOT:
			return "Unexpected dot."
		ERR_UNEXPECTED_BOOLEAN:
			return "Unexpected boolean."
		ERR_UNEXPECTED_STRING:
			return "Unexpected string."
		ERR_UNEXPECTED_NUMBER:
			return "Unexpected number."
		ERR_UNEXPECTED_VARIABLE:
			return "Unexpected variable."
		ERR_INVALID_INDEX:
			return "Invalid index."
		ERR_UNEXPECTED_ASSIGNMENT:
			return "Unexpected assignment."

	return "Unknown syntax."

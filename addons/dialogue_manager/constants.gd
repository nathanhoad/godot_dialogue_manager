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
const TOKEN_CONDITION = "condition"
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

# Runtime primitive methods

const SUPPORTED_PRIMITIVES = [TYPE_ARRAY, TYPE_DICTIONARY, TYPE_QUATERNION, TYPE_COLOR, TYPE_SIGNAL]
const SUPPORTED_ARRAY_METHODS = [
	"assign",
	"append",
	"append_array",
	"back",
	"count",
	"clear",
	"erase",
	"has",
	"insert",
	"is_empty",
	"max",
	"min",
	"pick_random",
	"pop_at",
	"pop_back",
	"pop_front",
	"push_back",
	"push_front",
	"remove_at",
	"reverse",
	"shuffle",
	"size",
	"sort"
]
const SUPPORTED_DICTIONARY_METHODS = ["has", "has_all", "get", "keys", "values", "size"]
const SUPPORTED_QUATERNION_METHODS = [
	"angle_to",
	"dot",
	"exp",
	"from_euler",
	"get_angle",
	"get_axis",
	"get_euler",
	"inverse",
	"is_equal_approx",
	"is_finite",
	"is_normalized",
	"length",
	"length_squared",
	"log",
	"normalized",
	"slerp",
	"slerpni",
	"spherical_cubic_interpolate",
	"spherical_cubic_interpolate_in_time"
]
const SUPPORTED_COLOR_METHODS = [
	"blend",
	"clamp",
	"darkened",
	"from_hsv",
	"from_ok_hsl",
	"from_rgbe9995",
	"from_string",
	"get_luminance",
	"hex",
	"hex64",
	"html",
	"html_is_valid",
	"inverted",
	"is_equal_approx",
	"lerp",
	"lightened",
	"linear_to_srgb",
	"srgb_to_linear",
	"to_abgr32",
	"to_abgr64",
	"to_argb32",
	"to_argb64",
	"to_html",
	"to_rgba32",
	"to_rgba64"
]

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
const ERR_UNEXPECTED_CONDITION = 111
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
const ERR_UNKNOWN_USING = 135


## Get the error message
static func get_error_message(error: int) -> String:
	match error:
		ERR_ERRORS_IN_IMPORTED_FILE:
			return translate("errors.import_errors")
		ERR_FILE_ALREADY_IMPORTED:
			return translate("errors.already_imported")
		ERR_DUPLICATE_IMPORT_NAME:
			return translate("errors.duplicate_import")
		ERR_EMPTY_TITLE:
			return translate("errors.empty_title")
		ERR_DUPLICATE_TITLE:
			return translate("errors.duplicate_title")
		ERR_NESTED_TITLE:
			return translate("errors.nested_title")
		ERR_TITLE_INVALID_CHARACTERS:
			return translate("errors.invalid_title_string")
		ERR_TITLE_BEGINS_WITH_NUMBER:
			return translate("errors.invalid_title_number")
		ERR_UNKNOWN_TITLE:
			return translate("errors.unknown_title")
		ERR_INVALID_TITLE_REFERENCE:
			return translate("errors.jump_to_invalid_title")
		ERR_TITLE_REFERENCE_HAS_NO_CONTENT:
			return translate("errors.title_has_no_content")
		ERR_INVALID_EXPRESSION:
			return translate("errors.invalid_expression")
		ERR_UNEXPECTED_CONDITION:
			return translate("errors.unexpected_condition")
		ERR_DUPLICATE_ID:
			return translate("errors.duplicate_id")
		ERR_MISSING_ID:
			return translate("errors.missing_id")
		ERR_INVALID_INDENTATION:
			return translate("errors.invalid_indentation")
		ERR_INVALID_CONDITION_INDENTATION:
			return translate("errors.condition_has_no_content")
		ERR_INCOMPLETE_EXPRESSION:
			return translate("errors.incomplete_expression")
		ERR_INVALID_EXPRESSION_FOR_VALUE:
			return translate("errors.invalid_expression_for_value")
		ERR_FILE_NOT_FOUND:
			return translate("errors.file_not_found")
		ERR_UNEXPECTED_END_OF_EXPRESSION:
			return translate("errors.unexpected_end_of_expression")
		ERR_UNEXPECTED_FUNCTION:
			return translate("errors.unexpected_function")
		ERR_UNEXPECTED_BRACKET:
			return translate("errors.unexpected_bracket")
		ERR_UNEXPECTED_CLOSING_BRACKET:
			return translate("errors.unexpected_closing_bracket")
		ERR_MISSING_CLOSING_BRACKET:
			return translate("errors.missing_closing_bracket")
		ERR_UNEXPECTED_OPERATOR:
			return translate("errors.unexpected_operator")
		ERR_UNEXPECTED_COMMA:
			return translate("errors.unexpected_comma")
		ERR_UNEXPECTED_COLON:
			return translate("errors.unexpected_colon")
		ERR_UNEXPECTED_DOT:
			return translate("errors.unexpected_dot")
		ERR_UNEXPECTED_BOOLEAN:
			return translate("errors.unexpected_boolean")
		ERR_UNEXPECTED_STRING:
			return translate("errors.unexpected_string")
		ERR_UNEXPECTED_NUMBER:
			return translate("errors.unexpected_number")
		ERR_UNEXPECTED_VARIABLE:
			return translate("errors.unexpected_variable")
		ERR_INVALID_INDEX:
			return translate("errors.invalid_index")
		ERR_UNEXPECTED_ASSIGNMENT:
			return translate("errors.unexpected_assignment")
		ERR_UNKNOWN_USING:
			return translate("errors.unknown_using")

	return translate("errors.unknown")


static func translate(string: String) -> String:
	var language: String = TranslationServer.get_tool_locale()
	var translations_path: String = "res://addons/dialogue_manager/l10n/%s.po" % language
	var fallback_translations_path: String = "res://addons/dialogue_manager/l10n/"+TranslationServer.get_tool_locale().substr(0, 2)+".po"
	var en_translations_path: String = "res://addons/dialogue_manager/l10n/en.po"
	var translations: Translation = load(translations_path if FileAccess.file_exists(translations_path) else (fallback_translations_path if FileAccess.file_exists(fallback_translations_path) else en_translations_path))
	return translations.get_message(string)

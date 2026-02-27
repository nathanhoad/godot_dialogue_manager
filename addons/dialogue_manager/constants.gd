class_name DMConstants extends RefCounted


const USER_CONFIG_PATH: String = "user://dialogue_manager_user_config.json"


enum MutationBehaviour {
	Wait,
	DoNotWait,
	Skip
}

# Token types

const TOKEN_FUNCTION: StringName = &"function"
const TOKEN_DICTIONARY_REFERENCE: StringName = &"dictionary_reference"
const TOKEN_DICTIONARY_NESTED_REFERENCE: StringName = &"dictionary_nested_reference"
const TOKEN_GROUP: StringName = &"group"
const TOKEN_ARRAY: StringName = &"array"
const TOKEN_DICTIONARY: StringName = &"dictionary"
const TOKEN_PARENS_OPEN: StringName = &"parens_open"
const TOKEN_PARENS_CLOSE: StringName = &"parens_close"
const TOKEN_BRACKET_OPEN: StringName = &"bracket_open"
const TOKEN_BRACKET_CLOSE: StringName = &"bracket_close"
const TOKEN_BRACE_OPEN: StringName = &"brace_open"
const TOKEN_BRACE_CLOSE: StringName = &"brace_close"
const TOKEN_COLON: StringName = &"colon"
const TOKEN_COMPARISON: StringName = &"comparison"
const TOKEN_ASSIGNMENT: StringName = &"assignment"
const TOKEN_OPERATOR: StringName = &"operator"
const TOKEN_COMMA: StringName = &"comma"
const TOKEN_NULL_COALESCE: StringName = &"null_coalesce"
const TOKEN_DOT: StringName = &"dot"
const TOKEN_CONDITION: StringName = &"condition"
const TOKEN_BOOL: StringName = &"bool"
const TOKEN_NOT: StringName = &"not"
const TOKEN_AND_OR: StringName = &"and_or"
const TOKEN_STRING: StringName = &"string"
const TOKEN_NUMBER: StringName = &"number"
const TOKEN_VARIABLE: StringName = &"variable"
const TOKEN_COMMENT: StringName = &"comment"

const TOKEN_VALUE: StringName = &"value"
const TOKEN_ERROR: StringName = &"error"

# Line types

const TYPE_UNKNOWN: StringName = &""
const TYPE_IMPORT: StringName = &"import"
const TYPE_USING: StringName = &"using"
const TYPE_COMMENT: StringName = &"comment"
const TYPE_RESPONSE: StringName = &"response"
const TYPE_LABEL: StringName = &"label"
const TYPE_CONDITION: StringName = &"condition"
const TYPE_WHILE: StringName = &"while"
const TYPE_MATCH: StringName = &"match"
const TYPE_WHEN: StringName = &"when"
const TYPE_MUTATION: StringName = &"mutation"
const TYPE_GOTO: StringName = &"goto"
const TYPE_DIALOGUE: StringName = &"dialogue"
const TYPE_RANDOM: StringName = &"random"
const TYPE_ERROR: StringName = &"error"

# Line IDs

const ID_NULL: StringName = &""
const ID_ERROR: StringName = &"error"
const ID_END: StringName = &"end"
const ID_END_CONVERSATION: StringName = &"end!"

# Errors

const ERR_ERRORS_IN_IMPORTED_FILE: int = 100
const ERR_FILE_ALREADY_IMPORTED: int = 101
const ERR_DUPLICATE_IMPORT_NAME: int = 102
const ERR_EMPTY_LABEL: int = 103
const ERR_DUPLICATE_LABEL: int = 104
const ERR_LABEL_INVALID_CHARACTERS: int = 106
const ERR_UNKNOWN_LABEL: int = 107
const ERR_INVALID_LABEL_REFERENCE: int= 108
const ERR_LABEL_REFERENCE_HAS_NO_CONTENT: int = 109
const ERR_INVALID_EXPRESSION: int = 110
const ERR_UNEXPECTED_CONDITION: int = 111
const ERR_DUPLICATE_ID: int = 112
const ERR_MISSING_ID: int = 113
const ERR_INVALID_INDENTATION: int = 114
const ERR_INVALID_CONDITION_INDENTATION: int = 115
const ERR_INCOMPLETE_EXPRESSION: int = 116
const ERR_INVALID_EXPRESSION_FOR_VALUE: int = 117
const ERR_UNKNOWN_LINE_SYNTAX: int = 118
const ERR_LABEL_BEGINS_WITH_NUMBER: int = 119
const ERR_UNEXPECTED_END_OF_EXPRESSION: int = 120
const ERR_UNEXPECTED_FUNCTION: int = 121
const ERR_UNEXPECTED_BRACKET: int = 122
const ERR_UNEXPECTED_CLOSING_BRACKET: int = 123
const ERR_MISSING_CLOSING_BRACKET: int = 124
const ERR_UNEXPECTED_OPERATOR: int = 125
const ERR_UNEXPECTED_COMMA: int = 126
const ERR_UNEXPECTED_COLON: int = 127
const ERR_UNEXPECTED_DOT: int = 128
const ERR_UNEXPECTED_BOOLEAN: int = 129
const ERR_UNEXPECTED_STRING: int = 130
const ERR_UNEXPECTED_NUMBER: int = 131
const ERR_UNEXPECTED_VARIABLE: int = 132
const ERR_INVALID_INDEX: int = 133
const ERR_UNEXPECTED_ASSIGNMENT: int = 134
const ERR_UNKNOWN_USING: int = 135
const ERR_EXPECTED_WHEN_OR_ELSE: int = 136
const ERR_ONLY_ONE_ELSE_ALLOWED: int = 137
const ERR_WHEN_MUST_BELONG_TO_MATCH: int = 138
const ERR_CONCURRENT_LINE_WITHOUT_ORIGIN: int = 139
const ERR_GOTO_NOT_ALLOWED_ON_CONCURRECT_LINES: int = 140
const ERR_UNEXPECTED_SYNTAX_ON_NESTED_DIALOGUE_LINE: int = 141
const ERR_NESTED_DIALOGUE_INVALID_JUMP: int = 142
const ERR_MISSING_RESOURCE_FOR_AUTOSTART: int = 143


static var _current_locale: String = ""
static var _current_translation: Translation


## Get the error message
static func get_error_message(error: int) -> String:
	match error:
		ERR_ERRORS_IN_IMPORTED_FILE:
			return translate(&"errors.import_errors")
		ERR_FILE_ALREADY_IMPORTED:
			return translate(&"errors.already_imported")
		ERR_DUPLICATE_IMPORT_NAME:
			return translate(&"errors.duplicate_import")
		ERR_EMPTY_LABEL:
			return translate(&"errors.empty_label")
		ERR_DUPLICATE_LABEL:
			return translate(&"errors.duplicate_label")
		ERR_LABEL_INVALID_CHARACTERS:
			return translate(&"errors.invalid_label_string")
		ERR_LABEL_BEGINS_WITH_NUMBER:
			return translate(&"errors.invalid_label_number")
		ERR_UNKNOWN_LABEL:
			return translate(&"errors.unknown_label")
		ERR_INVALID_LABEL_REFERENCE:
			return translate(&"errors.jump_to_invalid_label")
		ERR_LABEL_REFERENCE_HAS_NO_CONTENT:
			return translate(&"errors.label_has_no_content")
		ERR_INVALID_EXPRESSION:
			return translate(&"errors.invalid_expression")
		ERR_UNEXPECTED_CONDITION:
			return translate(&"errors.unexpected_condition")
		ERR_DUPLICATE_ID:
			return translate(&"errors.duplicate_id")
		ERR_MISSING_ID:
			return translate(&"errors.missing_id")
		ERR_INVALID_INDENTATION:
			return translate(&"errors.invalid_indentation")
		ERR_INVALID_CONDITION_INDENTATION:
			return translate(&"errors.condition_has_no_content")
		ERR_INCOMPLETE_EXPRESSION:
			return translate(&"errors.incomplete_expression")
		ERR_INVALID_EXPRESSION_FOR_VALUE:
			return translate(&"errors.invalid_expression_for_value")
		ERR_FILE_NOT_FOUND:
			return translate(&"errors.file_not_found")
		ERR_UNEXPECTED_END_OF_EXPRESSION:
			return translate(&"errors.unexpected_end_of_expression")
		ERR_UNEXPECTED_FUNCTION:
			return translate(&"errors.unexpected_function")
		ERR_UNEXPECTED_BRACKET:
			return translate(&"errors.unexpected_bracket")
		ERR_UNEXPECTED_CLOSING_BRACKET:
			return translate(&"errors.unexpected_closing_bracket")
		ERR_MISSING_CLOSING_BRACKET:
			return translate(&"errors.missing_closing_bracket")
		ERR_UNEXPECTED_OPERATOR:
			return translate(&"errors.unexpected_operator")
		ERR_UNEXPECTED_COMMA:
			return translate(&"errors.unexpected_comma")
		ERR_UNEXPECTED_COLON:
			return translate(&"errors.unexpected_colon")
		ERR_UNEXPECTED_DOT:
			return translate(&"errors.unexpected_dot")
		ERR_UNEXPECTED_BOOLEAN:
			return translate(&"errors.unexpected_boolean")
		ERR_UNEXPECTED_STRING:
			return translate(&"errors.unexpected_string")
		ERR_UNEXPECTED_NUMBER:
			return translate(&"errors.unexpected_number")
		ERR_UNEXPECTED_VARIABLE:
			return translate(&"errors.unexpected_variable")
		ERR_INVALID_INDEX:
			return translate(&"errors.invalid_index")
		ERR_UNEXPECTED_ASSIGNMENT:
			return translate(&"errors.unexpected_assignment")
		ERR_UNKNOWN_USING:
			return translate(&"errors.unknown_using")
		ERR_EXPECTED_WHEN_OR_ELSE:
			return translate(&"errors.expected_when_or_else")
		ERR_ONLY_ONE_ELSE_ALLOWED:
			return translate(&"errors.only_one_else_allowed")
		ERR_WHEN_MUST_BELONG_TO_MATCH:
			return translate(&"errors.when_must_belong_to_match")
		ERR_CONCURRENT_LINE_WITHOUT_ORIGIN:
			return translate(&"errors.concurrent_line_without_origin")
		ERR_GOTO_NOT_ALLOWED_ON_CONCURRECT_LINES:
			return translate(&"errors.goto_not_allowed_on_concurrect_lines")
		ERR_UNEXPECTED_SYNTAX_ON_NESTED_DIALOGUE_LINE:
			return translate(&"errors.unexpected_syntax_on_nested_dialogue_line")
		ERR_NESTED_DIALOGUE_INVALID_JUMP:
			return translate(&"errors.err_nested_dialogue_invalid_jump")
		ERR_MISSING_RESOURCE_FOR_AUTOSTART:
			return translate(&"errors.missing_resource_for_autostart")

	return translate(&"errors.unknown")


static func translate(string: String) -> String:
	var locale: String = TranslationServer.get_tool_locale()
	if _current_translation == null or _current_locale != locale:
		var base_path: String = new().get_script().resource_path.get_base_dir()
		var translation_path: String = "%s/l10n/%s.po" % [base_path, locale]
		var fallback_translation_path: String = "%s/l10n/%s.po" % [base_path, locale.substr(0, 2)]
		var en_translation_path: String = "%s/l10n/en.po" % base_path
		_current_translation = load(translation_path if FileAccess.file_exists(translation_path) else (fallback_translation_path if FileAccess.file_exists(fallback_translation_path) else en_translation_path))
		_current_locale = locale
	return _current_translation.get_message(string)

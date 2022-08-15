extends Node


const SYNTAX_VERSION = 2
const CONFIG_PATH = "res://dialogue.cfg"

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
const TOKEN_COMMMENT = "comment"

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
const ID_TITLE_HAS_NO_BODY = "title has no body"
const ID_END = "end"
const ID_END_CONVERSATION = "end!"

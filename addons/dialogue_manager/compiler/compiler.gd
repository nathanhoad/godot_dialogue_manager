## A compiler of Dialogue Manager dialogue.
class_name DMCompiler extends RefCounted


## Compile a dialogue script.
static func compile_string(text: String, path: String) -> DMCompilerResult:
	var compilation: DMCompilation = DMCompilation.new()
	compilation.compile(text, path)

	var result: DMCompilerResult = DMCompilerResult.new()
	result.imported_paths = compilation.imported_paths
	result.using_states = compilation.using_states
	result.character_names = compilation.character_names
	result.titles = compilation.titles
	result.first_title = compilation.first_title
	result.errors = compilation.errors
	result.lines = compilation.data
	result.raw_text = text

	return result


## Get the line type of a string. The returned string will match one of the [code]TYPE_[/code] constants of [DMConstants].
static func get_line_type(text: String) -> String:
	var compilation: DMCompilation = DMCompilation.new()
	return compilation.get_line_type(text)


## Get the static line ID (eg. [code][ID:SOMETHING][/code]) of some text.
static func get_static_line_id(text: String) -> String:
	var compilation: DMCompilation = DMCompilation.new()
	return compilation.extract_static_line_id(text)


## Get the translatable part of a line.
static func extract_translatable_string(text: String) -> String:
	var compilation: DMCompilation = DMCompilation.new()

	var tree_line = DMTreeLine.new("")
	tree_line.text = text
	var line: DMCompiledLine = DMCompiledLine.new("", compilation.get_line_type(text))
	compilation.parse_character_and_dialogue(tree_line, line, [tree_line], 0, null)

	return line.text


## Extract a mutation from a string.
static func extract_mutation(text: String) -> Dictionary:
	var compilation: DMCompilation = DMCompilation.new()
	return compilation.extract_mutation(text)


## Get the known titles in a dialogue script.
static func get_titles_in_text(text: String, path: String) -> Dictionary:
	var compilation: DMCompilation = DMCompilation.new()
	compilation.build_line_tree(compilation.inject_imported_files(text, path))
	return compilation.titles

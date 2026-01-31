@tool
class_name DMCodeEdit extends CodeEdit


signal active_title_change(title: String)
signal error_clicked(line_number: int)
signal external_file_requested(path: String, title: String)


const MUTATION_PREFIXES: PackedStringArray = ["$>", "$>>", "do ", "do! ", "set ", "if ", "elif ", "else if ", "match ", "when "]
const INLINE_MUTATION_PREFIXES: PackedStringArray = ["$> ", "$>> ", "do ", "do! ", "set ", "if ", "elif "]

# A link back to the owner `MainView`
var main_view: Control

# Theme overrides for syntax highlighting, etc
var theme_overrides: Dictionary:
	set(value):
		theme_overrides = value

		syntax_highlighter = DMSyntaxHighlighter.new()

		# General UI
		add_theme_color_override("font_color", theme_overrides.text_color)
		add_theme_color_override("background_color", theme_overrides.background_color)
		add_theme_color_override("current_line_color", theme_overrides.current_line_color)
		add_theme_font_override("font", get_theme_font("source", "EditorFonts"))
		add_theme_font_size_override("font_size", theme_overrides.font_size * theme_overrides.scale)
		font_size = round(theme_overrides.font_size)
	get:
		return theme_overrides

# Any parse errors
var errors: Array:
	set(next_errors):
		errors = next_errors
		for i in range(0, get_line_count()):
			var is_error: bool = false
			for error in errors:
				if error.line_number == i:
					is_error = true
			mark_line_as_error(i, is_error)
		_on_code_edit_caret_changed()
	get:
		return errors

# The last selection (if there was one) so we can remember it for refocusing
var last_selected_text: String

var font_size: int:
	set(value):
		font_size = value
		add_theme_font_size_override("font_size", font_size * theme_overrides.scale)
	get:
		return font_size

var WEIGHTED_RANDOM_PREFIX: RegEx = RegEx.create_from_string("^\\%[\\d.]+\\s")
var STATIC_REGEX: RegEx = RegEx.create_from_string("^static var (?<property>[a-zA-Z_0-9]+)(:\\s?(?<type>[a-zA-Z_0-9]+))?")
var STATIC_CONTENT_REGEX: RegEx = RegEx.create_from_string("static (var|func)")

var compiler_regex: DMCompilerRegEx = DMCompilerRegEx.new()
var _autoloads: Dictionary[String, String] = {}
var _autoload_member_cache: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	# Add error gutter
	add_gutter(0)
	set_gutter_type(0, TextEdit.GUTTER_TYPE_ICON)

	# Add comment delimiter
	if not has_comment_delimiter("#"):
		add_comment_delimiter("#", "", true)

	syntax_highlighter = DMSyntaxHighlighter.new()

	# Keep track of any autoloads
	ProjectSettings.settings_changed.connect(_on_project_settings_changed)
	_on_project_settings_changed()


func _gui_input(event: InputEvent) -> void:
	# Handle shortcuts that come from the editor
	if event is InputEventKey and event.is_pressed():
		var shortcut: String = DMPlugin.get_editor_shortcut(event)
		match shortcut:
			"toggle_comment":
				toggle_comment()
				get_viewport().set_input_as_handled()
			"delete_line":
				delete_current_line()
				get_viewport().set_input_as_handled()
			"move_up":
				move_line(-1)
				get_viewport().set_input_as_handled()
			"move_down":
				move_line(1)
				get_viewport().set_input_as_handled()
			"text_size_increase":
				self.font_size += 1
				get_viewport().set_input_as_handled()
			"text_size_decrease":
				self.font_size -= 1
				get_viewport().set_input_as_handled()
			"text_size_reset":
				self.font_size = theme_overrides.font_size
				get_viewport().set_input_as_handled()
			"make_bold":
				insert_bbcode("[b]", "[/b]")
				get_viewport().set_input_as_handled()
			"make_italic":
				insert_bbcode("[i]", "[/i]")
				get_viewport().set_input_as_handled()

	elif event is InputEventMouse:
		match event.as_text():
			"Ctrl+Mouse Wheel Up", "Command+Mouse Wheel Up":
				self.font_size += 1
				get_viewport().set_input_as_handled()
			"Ctrl+Mouse Wheel Down", "Command+Mouse Wheel Down":
				self.font_size -= 1
				get_viewport().set_input_as_handled()


func _can_drop_data(at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY: return false
	if data.type != "files": return false

	var files: PackedStringArray = Array(data.files)
	return files.size() > 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var replace_regex: RegEx = RegEx.create_from_string("[^a-zA-Z_0-9]+")

	if typeof(data) == TYPE_STRING: return

	var files: PackedStringArray = Array(data.files)
	for file: String in files:
		# Don't import the file into itself
		if file == main_view.current_file_path: continue

		if file.get_extension() == "dialogue":
			var known_aliases: PackedStringArray = []
			var path: String = file.replace("res://", "").replace(".dialogue", "")
			# Find the first non-import line in the file to add our import
			var lines: PackedStringArray = text.split("\n")
			for i: int in range(0, lines.size()):
				if lines[i].begins_with("import "):
					var found: RegExMatch = compiler_regex.IMPORT_REGEX.search(lines[i])
					if found:
						known_aliases.append(found.strings[found.names.prefix])
				else:
					var alias: String = ""
					var bits: PackedStringArray = replace_regex.sub(path, "|", true).split("|")
					bits.reverse()
					for end: int in range(1, bits.size() + 1):
						alias =  "_".join(bits.slice(0, end))
						if not alias in known_aliases:
							break
					insert_line_at(i, "import \"%s\" as %s\n" % [file, alias])
					set_caret_line(i)
					break
		else:
			var cursor: Vector2 = get_line_column_at_pos(at_position)
			if cursor.x > -1 and cursor.y > -1:
				set_cursor(cursor)
				remove_secondary_carets()
				var resource: Resource = load(file)
				# If the dropped file is an audio stream then assume it's a voice reference
				if is_instance_of(resource, AudioStream):
					var current_voice_regex: RegEx = RegEx.create_from_string("\\[#voice=.+\\]")
					var path: String = ResourceUID.call("path_to_uid", file) if ResourceUID.has_method("path_to_uid") else file
					var line_text: String = get_line(cursor.y)
					var voice_text: String = "[#voice=%s]" % [path]
					if current_voice_regex.search(line_text):
						set_line(cursor.y, current_voice_regex.replace(get_line(cursor.y), voice_text))
					else:
						insert_text(" " + voice_text, cursor.y, line_text.length())
				# Other wise it's just a file reference
				else:
					insert_text("\"%s\"" % file, cursor.y, cursor.x)
	grab_focus()


func _request_code_completion(force: bool) -> void:
	var cursor: Vector2 = get_cursor()
	var current_line: String = get_line(cursor.y)

	_add_jump_completions(current_line, cursor)
	_add_character_name_completions(current_line)
	_add_mutation_completions(current_line, cursor)

	update_code_completion_options(true)
	if get_code_completion_options().size() == 0:
		cancel_code_completion()


func _filter_code_completion_candidates(candidates: Array) -> Array:
	# Not sure why but if this method isn't overridden then all completions are wrapped in quotes.
	return candidates


func _confirm_code_completion(replace: bool) -> void:
	var completion: Dictionary = get_code_completion_option(get_code_completion_selected_index())
	begin_complex_operation()
	# Delete any part of the text that we've already typed
	for i: int in range(0, completion.display_text.length() - completion.insert_text.length()):
		backspace()
	# Insert the whole match
	insert_text_at_caret(completion.display_text)
	end_complex_operation()

	if completion.display_text.ends_with("()"):
		set_cursor(get_cursor() - Vector2.RIGHT)

	# Close the autocomplete menu on the next tick
	call_deferred("cancel_code_completion")


#region Completion Helpers


# Add completions for jump targets (=> and =><).
func _add_jump_completions(current_line: String, cursor: Vector2) -> void:
	if not ("=> " in current_line or "=>< " in current_line): return
	if cursor.x <= current_line.find("=>"): return

	var prompt: String = current_line.split("=>")[1]
	if prompt.begins_with("< "):
		prompt = prompt.substr(2)
	else:
		prompt = prompt.substr(1)

	if "=> " in current_line:
		if _matches_prompt(prompt, "end"):
			add_code_completion_option(CodeEdit.KIND_CLASS, "END", "END".substr(prompt.length()), theme_overrides.text_color, get_theme_icon("Stop", "EditorIcons"))
		if _matches_prompt(prompt, "end!"):
			add_code_completion_option(CodeEdit.KIND_CLASS, "END!", "END!".substr(prompt.length()), theme_overrides.text_color, get_theme_icon("Stop", "EditorIcons"))

	# Get all titles, including those in imports
	for title: String in DMCompiler.get_titles_in_text(text, main_view.current_file_path):
		# Ignore any imported titles that aren't resolved to human readable.
		if title.to_int() > 0:
			continue
		elif "/" in title:
			var bits: PackedStringArray = title.split("/")
			if _matches_prompt(prompt, bits[0]) or _matches_prompt(prompt, bits[1]):
				add_code_completion_option(CodeEdit.KIND_CLASS, title, title.substr(prompt.length()), theme_overrides.text_color, get_theme_icon("CombineLines", "EditorIcons"))
		elif _matches_prompt(prompt, title):
			add_code_completion_option(CodeEdit.KIND_CLASS, title, title.substr(prompt.length()), theme_overrides.text_color, get_theme_icon("ArrowRight", "EditorIcons"))


# Add completions for character names at the start of dialogue lines.
func _add_character_name_completions(current_line: String) -> void:
	# Ignore names on mutation lines
	for prefix: String in MUTATION_PREFIXES:
		if current_line.strip_edges().begins_with(prefix):
			return

	var name_so_far: String = WEIGHTED_RANDOM_PREFIX.sub(current_line.strip_edges(), "")
	if name_so_far == "" or name_so_far[0].to_upper() != name_so_far[0]:
		return

	var names: PackedStringArray = get_character_names(name_so_far)
	for character_name: String in names:
		add_code_completion_option(CodeEdit.KIND_CLASS, character_name + ": ", character_name.substr(name_so_far.length()) + ": ", theme_overrides.text_color, get_theme_icon("Sprite2D", "EditorIcons"))


# Add state/mutation completions.
func _add_mutation_completions(current_line: String, cursor: Vector2) -> void:
	# Check for inline mutation context first (e.g., "Nathan: Hello [$> SomeGlobal.")
	var inline_context: Dictionary = _get_inline_mutation_context(current_line, cursor.x)
	var mutation_expression: String = ""
	var is_inline_mutation: bool = not inline_context.is_empty()
	var is_using_line: bool = false

	if is_inline_mutation:
		mutation_expression = inline_context.get("expression", "")
	else:
		# Match autoloads on full mutation lines (MUTATION_PREFIXES + "using ")
		for prefix in MUTATION_PREFIXES + PackedStringArray(["using "]):
			if current_line.strip_edges().begins_with(prefix) and cursor.x > current_line.find(prefix):
				mutation_expression = current_line.substr(0, cursor.x).strip_edges().substr(3)
				is_using_line = current_line.strip_edges().begins_with("using ")
				break

	if mutation_expression == "" and not is_inline_mutation:
		return

	# Find the last token (the part being typed)
	var possible_prompt: String = mutation_expression.reverse()
	possible_prompt = possible_prompt.substr(0, possible_prompt.find(" "))
	possible_prompt = possible_prompt.substr(0, possible_prompt.find("("))
	possible_prompt = possible_prompt.reverse()
	var segments: PackedStringArray = possible_prompt.split(".")
	var auto_completes: Array[Dictionary] = []

	if segments.size() == 1:
		# Suggest autoloads and state shortcuts
		auto_completes = _get_autoload_completions(segments[0])
	elif not is_using_line:
		if not segments[0] in _autoloads.keys():
			# See if the first segment is a property of a shortcut
			var shortcut: String = _find_shortcut_with_member(segments[0])
			if not shortcut.is_empty():
				segments.insert(0, shortcut)
		# Suggest members of an autoload or nested property
		auto_completes = _get_member_completions(segments)

	var prompt: String = segments[-1].to_lower()

	# Add true/false
	if prompt.length() > 1:
		var icon: Texture2D = _get_icon_for_type("keyword")
		var color: Color = theme_overrides.conditions_color
		if "true".contains(prompt):
			add_code_completion_option(CodeEdit.KIND_CONSTANT, "true", "true".substr(prompt.length()), color, icon)
		if "false".contains(prompt):
			add_code_completion_option(CodeEdit.KIND_CONSTANT, "false", "false".substr(prompt.length()), color, icon)

	auto_completes.sort_custom(func(a, b):
		return a.text.to_lower().similarity(prompt) > b.text.to_lower().similarity(prompt)
	)
	for auto_complete: Dictionary in auto_completes:
		var icon: Texture2D = _get_icon_for_type(auto_complete.type)
		var display_text: String = auto_complete.text
		if auto_complete.type == "method":
			display_text += "()"
		var insert: String = display_text.substr(auto_complete.prompt.length())
		add_code_completion_option(CodeEdit.KIND_CLASS, display_text, insert, theme_overrides.text_color, icon)


# Find the shortcut that a member name belongs to.
func _find_shortcut_with_member(member_name: String) -> String:
	for autoload: String in _get_state_shortcuts():
		for member: Dictionary in _get_members_for_base_script(autoload):
			if member.name == member_name:
				return autoload
	return ""


# Get completions for autoload names and state shortcut members.
func _get_autoload_completions(prompt: String) -> Array[Dictionary]:
	var completions: Array[Dictionary] = []
	for autoload: String in _autoloads.keys():
		if _matches_prompt(prompt, autoload):
			completions.append({ prompt = prompt, text = autoload, type = "script" })
	for autoload: String in _get_state_shortcuts():
		for member: Dictionary in _get_members_for_base_script(autoload):
			if _matches_prompt(prompt, member.name):
				completions.append({ prompt = prompt, text = member.name, type = member.type })
	return completions


# Get completions for members of an autoload or nested property chain.
func _get_member_completions(segments: PackedStringArray) -> Array[Dictionary]:
	var completions: Array[Dictionary] = []
	var prompt: String = segments[-1]
	var members: Array[Dictionary] = []

	if segments.size() == 2:
		# Direct autoload property access (e.g., "SomeGlobal.property")
		members = _get_members_for_base_script(segments[0])
	else:
		# Nested property access (e.g., "SomeGlobal.a_class_property.nested")
		var chain_segments: PackedStringArray = segments.slice(0, segments.size() - 1)
		var resolved_script: Variant = _resolve_script_for_property_chain(chain_segments)
		if resolved_script != null:
			members = _get_members_for_script(resolved_script)

	for member: Dictionary in members:
		if _matches_prompt(prompt, member.name):
			completions.append({ prompt = prompt, text = member.name, type = member.type })
	return completions


# Get the appropriate icon for a member type.
func _get_icon_for_type(type: String) -> Texture2D:
	match type:
		"keyword":
			return get_theme_icon("CodeHighlighter", "EditorIcons")
		"script":
			return get_theme_icon("Script", "EditorIcons")
		"property":
			return get_theme_icon("MemberProperty", "EditorIcons")
		"method":
			return get_theme_icon("MemberMethod", "EditorIcons")
		"signal":
			return get_theme_icon("MemberSignal", "EditorIcons")
		"constant":
			return get_theme_icon("MemberConstant", "EditorIcons")
		"enum":
			return get_theme_icon("Enum", "EditorIcons")
	return null


#endregion

#region Cursor Helpers


## Get the current caret position as a Vector2 (x=column, y=line).
func get_cursor() -> Vector2:
	return Vector2(get_caret_column(), get_caret_line())


## Set the caret position from a Vector2 (x=column, y=line).
func set_cursor(from_cursor: Vector2) -> void:
	set_caret_line(from_cursor.y, false)
	set_caret_column(from_cursor.x, false)


# Check if a prompt fuzzy-matches a candidate.
func _matches_prompt(prompt: String, candidate: String) -> bool:
	if prompt.length() > candidate.length(): return false
	if prompt.is_empty(): return true

	# Fuzzy match characters in order
	candidate = candidate.to_lower()
	var next_index: int = 0
	for char: String in prompt.to_lower():
		next_index = candidate.find(char, next_index) + 1
		if next_index == 0:
			return false
	return true


#endregion

#region Autoload and Script Helpers


# Get autoload shortcuts from settings and "using" clauses.
func _get_state_shortcuts() -> PackedStringArray:
	# Get any shortcuts defined in settings
	var shortcuts: PackedStringArray = DMSettings.get_setting(DMSettings.STATE_AUTOLOAD_SHORTCUTS, [])
	# Check for "using" clauses
	for line: String in text.split("\n"):
		var found: RegExMatch = compiler_regex.USING_REGEX.search(line)
		if found:
			shortcuts.append(found.strings[found.names.state])
	# Check for any other script sources
	for extra_script_source: String in DMSettings.get_setting(DMSettings.EXTRA_AUTO_COMPLETE_SCRIPT_SOURCES, []):
		if extra_script_source:
			shortcuts.append(extra_script_source)

	return shortcuts


# Get all members (methods, properties, signals, constants) for an autoload.
func _get_members_for_base_script(base_script_name: String) -> Array[Dictionary]:
	# Debounce method list lookups
	if _autoload_member_cache.has(base_script_name) \
	and _autoload_member_cache.get(base_script_name).get("at") > Time.get_ticks_msec() - 10000:
		return _autoload_member_cache.get(base_script_name).get("members")

	if not _autoloads.has(base_script_name) \
	and not base_script_name.begins_with("res://") \
	and not base_script_name.begins_with("uid://"):
		return []

	var autoload: Variant = load(_autoloads.get(base_script_name, base_script_name))
	if autoload is PackedScene:
		var node: Node = autoload.instantiate()
		autoload = node.get_script()
		node.free()
	var script: Script = autoload if autoload is Script else autoload.get_script()

	if not is_instance_valid(script): return []

	var members: Array[Dictionary] = _get_members_for_script(script)

	_autoload_member_cache[base_script_name] = {
		at = Time.get_ticks_msec(),
		members = members
	}

	return members


# Get all members (methods, properties, signals, constants) for a Script.
func _get_members_for_script(script: Variant) -> Array[Dictionary]:
	var members: Array[Dictionary] = []

	# Its an enum:
	if script is Dictionary:
		for key: String in script.keys():
			members.append({
				name = key,
				type = "enum"
			})
		return members

	# Otherwise its a script
	if not is_instance_valid(script): return []

	if script.resource_path.is_empty() or script.resource_path.ends_with(".gd"):
		for m: Dictionary in script.get_script_method_list():
			if not m.name.begins_with("@"):
				members.append({
					name = m.name,
					type = "method"
				})
		for m: Dictionary in script.get_script_property_list():
			if not m.name.ends_with(".gd") and not m.name.contains("Built-in"):
				members.append({
					name = m.name,
					type = "property",
					"class_name" = m.get("class_name", "")
				})
		for m: Dictionary in script.get_script_signal_list():
			members.append({
				name = m.name,
				type = "signal"
			})
		for c: String in script.get_script_constant_map():
			members.append({
				name = c,
				type = "constant"
			})

		# Check for static properties
		for line: String in script.source_code.split("\n"):
			var matching: RegExMatch = STATIC_REGEX.search(line)
			if matching:
				members.append({
					name = matching.strings[matching.names.property],
					type = "property"
				})
	elif script.resource_path.ends_with(".cs"):
		var dotnet: RefCounted = load(DMPlugin.get_plugin_path() + "/DialogueManager.cs").new()
		for m: Dictionary in dotnet.GetMembersForScript(script):
			members.append(m)

	return members


# Get the Script for a given class name.
func _get_script_for_class_name(class_name_to_find: String) -> Script:
	if class_name_to_find == "": return null

	for class_data: Dictionary in ProjectSettings.get_global_class_list():
		if class_data.get(&"class") == class_name_to_find:
			return load(class_data.path)

	return null


# Get method info (args, return type) for a method in a Script.
func _get_method_info_from_script(script: Script, method_name: String) -> Dictionary:
	if not is_instance_valid(script): return {}

	if script.resource_path.ends_with(".gd"):
		for m: Dictionary in script.get_script_method_list():
			if m.name == method_name:
				return m
	elif script.resource_path.ends_with(".cs"):
		var dotnet: RefCounted = load(DMPlugin.get_plugin_path() + "/DialogueManager.cs").new()
		for m: Dictionary in dotnet.GetMembersForScript(script):
			if m.get("name") == method_name and m.get("type") == "method":
				return m

	return {}


# Format method arguments into a hint string for display.
func _format_method_hint(method_info: Dictionary) -> String:
	if method_info.is_empty(): return ""

	var args: Array = method_info.get("args", [])
	if args.size() == 0: return ""

	var hint_parts: PackedStringArray = []
	for arg: Dictionary in args:
		var arg_name: String = arg.get("name", "")
		var arg_type: int = arg.get("type", TYPE_NIL)
		var arg_class_name: String = arg.get("class_name", "")

		var type_name: String = ""
		if arg_class_name != "":
			type_name = arg_class_name
		elif arg_type != TYPE_NIL:
			type_name = type_string(arg_type)

		if type_name != "":
			hint_parts.append("%s: %s" % [arg_name, type_name])
		else:
			hint_parts.append(arg_name)

	return ", ".join(hint_parts)


#endregion

#region Symbol Resolution Helpers


# Find the line number where a member is defined in a script's source code.
func _find_definition_in_script(script: Script, member_name: String) -> int:
	if not is_instance_valid(script): return -1

	var lines: PackedStringArray = script.source_code.split("\n")

	var method_regex: RegEx = RegEx.create_from_string("^\\s*func\\s+" + member_name + "\\s*\\(")
	var property_regex: RegEx = RegEx.create_from_string("^\\s*var\\s+" + member_name + "\\s*[:\\s=]")
	var signal_regex: RegEx = RegEx.create_from_string("^\\s*signal\\s+" + member_name + "\\s*[\\(\\s]")
	var const_regex: RegEx = RegEx.create_from_string("^\\s*const\\s+" + member_name + "\\s*[:\\s=]")
	var enum_regex: RegEx = RegEx.create_from_string("^\\s*enum\\s+" + member_name + "[\\s$]")
	var inner_class_regex: RegEx = RegEx.create_from_string("^\\s*class\\s+" + member_name + ":")

	for i: int in range(lines.size()):
		var line: String = lines[i]
		if method_regex.search(line) \
		or property_regex.search(line) \
		or signal_regex.search(line) \
		or const_regex.search(line) \
		or enum_regex.search(line) \
		or inner_class_regex.search(line):
			# Editor line numbers start at 1
			return i + 1

	return -1


# Resolve the symbol at a given position in a mutation line for definition lookup.
func _resolve_mutation_symbol_at_position(line_text: String, column: int) -> Dictionary:
	if not _is_in_mutation_context(line_text, column):
		return {}

	var symbol: String = get_word_at_pos(get_local_mouse_pos())
	if symbol.is_empty(): return {}

	# Find the full chain by looking backwards from the token start for dots and identifiers
	var token_start: int = column
	while token_start > 0 and line_text[token_start - 1].is_valid_ascii_identifier():
		token_start -= 1

	var chain_start: int = token_start
	while chain_start > 0:
		var prev_char: String = line_text[chain_start - 1]
		if prev_char == ".":
			chain_start -= 1
			# Continue backwards to get the identifier before the dot
			while chain_start > 0 and line_text[chain_start - 1].is_valid_ascii_identifier():
				chain_start -= 1
		else:
			break

	var full_chain: String = line_text.substr(chain_start, token_start + symbol.length() - chain_start)
	# Remove any trailing parentheses content
	if "(" in full_chain:
		full_chain = full_chain.substr(0, full_chain.find("("))

	var segments: PackedStringArray = full_chain.split(".")

	# Check if it starts with an autoload
	if not segments[0] in _autoloads.keys():
		var shortcut: String = _find_shortcut_with_member(segments[0])
		if shortcut.is_empty():
			return {}
		else:
			segments.insert(0, shortcut)

	# The symbol we clicked on is the last segment
	var member_name: String = segments[-1]

	# Resolve the script that contains this member
	var target_script: Variant = null
	if segments.size() == 1 and segments[0] in _autoloads.keys():
		member_name = "class_name"
		var target: Variant = load(_autoloads.get(segments[0]))
		if target is PackedScene:
			var node: Node = target.instantiate()
			target = node.get_script()
			node.free()
		target_script = target if target is Script else target.get_script()
	else:
		var object_segments: PackedStringArray = segments.slice(0, segments.size() - 1)
		target_script = _resolve_script_for_property_chain(object_segments)

	if target_script == null:
		return {}
	elif target_script is Dictionary:
		return {
			"script": _resolve_script_for_property_chain(segments.slice(0, -2)),
			"member_name": segments.slice(0, -1)[segments.size() - 2],
			"symbol": symbol
		}
	# C# symbol lookups aren't supported
	if target_script is Script and target_script.resource_path.ends_with(".cs"):
		return {}

	return {
		"script": target_script,
		"member_name": member_name,
		"symbol": symbol
	}


# Update the code hint to show method parameter information.
func _update_code_hint() -> void:
	var cursor: Vector2 = get_cursor()
	var current_line: String = get_line(cursor.y)
	var text_before_cursor: String = current_line.substr(0, cursor.x)

	# Check if we're in a mutation context (inline or full line)
	var inline_context: Dictionary = _get_inline_mutation_context(current_line, cursor.x)
	if not _is_in_mutation_context(current_line, cursor.x):
		set_code_hint("")
		return

	# For inline mutations, scope to the bracket content
	var expression_text: String = text_before_cursor
	if not inline_context.is_empty():
		var bracket_start: int = inline_context.get("bracket_start", 0)
		expression_text = current_line.substr(bracket_start + 1, cursor.x - bracket_start - 1)

	# Check if cursor is inside parentheses by counting unmatched opening parens
	var paren_depth: int = 0
	var last_open_parenthesis_pos: int = -1
	for i: int in range(expression_text.length()):
		if expression_text[i] == "(":
			paren_depth += 1
			last_open_parenthesis_pos = i
		elif expression_text[i] == ")":
			paren_depth -= 1

	if paren_depth <= 0 or last_open_parenthesis_pos == -1:
		set_code_hint("")
		return

	# Extract the expression before the opening parenthesis
	var expression_before_parenthesis: String = expression_text.substr(0, last_open_parenthesis_pos).strip_edges()

	# Find the method chain (last token before the paren)
	var method_chain: String = ""
	for i: int in range(expression_before_parenthesis.length() - 1, -1, -1):
		var c: String = expression_before_parenthesis[i]
		if c == " " or c == "(" or c == "," or c == "=" or c == ">" or c == "!":
			method_chain = expression_before_parenthesis.substr(i + 1)
			break
		if i == 0:
			method_chain = expression_before_parenthesis

	if method_chain == "":
		set_code_hint("")
		return

	# Parse the method chain into segments
	var segments: PackedStringArray = method_chain.split(".")
	if segments.is_empty():
		set_code_hint("")
		return

	# The last segment is the method name
	var method_name: String = segments[-1]

	# Check if it starts with an autoload
	if not segments[0] in _autoloads.keys():
		var shortcut: String = _find_shortcut_with_member(segments[0])
		if shortcut.is_empty():
			set_code_hint("")
			return
		else:
			segments.insert(0, shortcut)

	# Resolve the script for the object the method is called on
	var object_segments: PackedStringArray = segments.slice(0, segments.size() - 1)
	var target_script: Variant = _resolve_script_for_property_chain(object_segments)

	if target_script == null or not target_script is Script:
		set_code_hint("")
		return

	# Get the method info and format the hint
	var method_info: Dictionary = _get_method_info_from_script(target_script, method_name)
	var hint: String = _format_method_hint(method_info)

	set_code_hint(hint)


#endregion

#region Mutation Context Helpers


# Get the inline mutation context if the cursor is inside an inline mutation bracket.
# Returns a dictionary with "expression" key containing the text to autocomplete,
# or an empty dictionary if not in an inline mutation context.
func _get_inline_mutation_context(line: String, cursor_x: int) -> Dictionary:
	# Find all bracket positions and determine if cursor is inside one
	var bracket_depth: int = 0
	var bracket_start: int = -1
	var bracket_content_start: int = -1

	for i: int in range(line.length()):
		if i >= cursor_x:
			break

		if line[i] == "[":
			bracket_depth += 1
			if bracket_depth == 1:
				bracket_start = i
				bracket_content_start = i + 1
		elif line[i] == "]":
			bracket_depth -= 1
			if bracket_depth == 0:
				bracket_start = -1
				bracket_content_start = -1

	# Not inside brackets
	if bracket_start == -1 or bracket_content_start == -1:
		return {}

	# Get the content inside the brackets up to cursor
	var bracket_content: String = line.substr(bracket_content_start, cursor_x - bracket_content_start)

	# Check if this is a mutation tag
	for prefix: String in INLINE_MUTATION_PREFIXES:
		if bracket_content.begins_with(prefix):
			# Return the expression part (after the tag)
			var expression: String = bracket_content.substr(prefix.length())
			return { "expression": expression, "bracket_start": bracket_start }

	return {}


# Check if the cursor is in a mutation context (either inline or full mutation line).
func _is_in_mutation_context(line: String, cursor_x: int) -> bool:
	if not _get_inline_mutation_context(line, cursor_x).is_empty():
		return true
	for prefix: String in MUTATION_PREFIXES:
		if line.strip_edges().begins_with(prefix):
			return true
	return false


# Resolve the Script for a chain of property accesses (e.g., "Autoload.prop1.prop2").
func _resolve_script_for_property_chain(segments: PackedStringArray) -> Variant:
	if segments.size() == 0: return null

	var autoload: Variant = null

	if segments[0].begins_with("uid://") or segments[0].begins_with("res://"):
		autoload = load(segments[0])
	elif _autoloads.has(segments[0]):
		autoload = load(_autoloads.get(segments[0]))
	else:
		return null

	if autoload is PackedScene:
		var node: Node = autoload.instantiate()
		autoload = node.get_script()
		node.free()
	elif not autoload is Script:
		autoload = autoload.get_script()

	var current_script: Variant = autoload

	if not is_instance_valid(current_script): return null
	if (segments.size() == 1): return current_script

	# Walk through each property in the chain (except the last one which is what we're completing)
	for i: int in range(1, segments.size()):
		var property_name: String = segments[i]
		var found_property: bool = false

		# Regular properties
		for property_info: Dictionary in current_script.get_script_property_list():
			if property_info.name == property_name:
				var prop_class_name: String = property_info.get("class_name", "")
				if prop_class_name != "":
					current_script = _get_script_for_class_name(prop_class_name)
					if current_script == null:
						return null
					found_property = true
					break
				else:
					# Property doesn't have a class type, can't go deeper
					return null

		# Check for inner classes and enums
		if not found_property:
			for constant: String in current_script.get_script_constant_map():
				if constant == property_name:
					var constant_value: Variant = current_script.get_script_constant_map().get(constant)
					# Inner class
					if constant_value is Script:
						current_script = constant_value
						found_property = true
						break
					# Enum
					if constant_value is Dictionary:
						current_script = constant_value
						found_property = true
						break
					else:
						# Constant isn't an enum or an inner class
						return null

		# Static properties. NOTE: Godot doesn't programatically find static properties
		# so we have to manually find them.
		if not found_property and current_script is Script and current_script.source_code.contains("static var"):
			for line: String in current_script.source_code.split("\n"):
				var matched: RegExMatch = STATIC_REGEX.search(line)
				if matched and matched.strings[matched.names.property] == property_name:
					if matched.names.has("type"):
						var type: String = matched.strings[matched.names.type]
						current_script = _get_script_for_class_name(type)
						if current_script == null:
							return null
						found_property = true
						break
					else:
						return null

		if not found_property:
			return null

	return current_script


#endregion

#region Title and Character Helpers


## Get a list of titles from the current text.
func get_titles() -> PackedStringArray:
	var titles: PackedStringArray = PackedStringArray([])
	var lines: PackedStringArray = text.split("\n")
	for line: String in lines:
		if line.strip_edges().begins_with("~ "):
			titles.append(line.strip_edges().substr(2))

	return titles


## Work out what the next title above the current line is
func check_active_title() -> void:
	var line_number: int = get_caret_line()
	var lines: PackedStringArray = text.split("\n")
	# Look at each line above this one to find the next title line
	for i: int in range(line_number, -1, -1):
		if lines[i].begins_with("~ "):
			active_title_change.emit(lines[i].replace("~ ", ""))
			return

	active_title_change.emit("")


## Move the caret line to match a given title.
func go_to_title(title: String, create_if_none: bool = false) -> void:
	var found_title: bool = false

	var lines = text.split("\n")
	for i: int in range(0, lines.size()):
		if lines[i].strip_edges() == "~ " + title:
			found_title = true
			set_caret_line(i)
			center_viewport_to_caret()

	if create_if_none and not found_title:
		text += "\n\n\n~ %s\n\n=> END" % [title]
		set_caret_line(text.split("\n").size() - 2)
		center_viewport_to_caret()


## Get all character names from the dialogue that match the given prefix.
func get_character_names(beginning_with: String) -> PackedStringArray:
	var names: PackedStringArray = []
	var lines = text.split("\n")
	for line: String in lines:
		if ": " in line:
			var character_name: String = WEIGHTED_RANDOM_PREFIX.sub(line.split(": ")[0].strip_edges(), "")
			if not character_name in names and _matches_prompt(beginning_with, character_name):
				names.append(character_name)
	return names


#endregion

#region Text Editing Helpers


## Mark a line as an error or not.
func mark_line_as_error(line_number: int, is_error: bool) -> void:
	# Lines display counting from 1 but are actually indexed from 0
	line_number -= 1

	if line_number < 0: return

	if is_error:
		set_line_background_color(line_number, theme_overrides.error_line_color)
		set_line_gutter_icon(line_number, 0, get_theme_icon("StatusError", "EditorIcons"))
	else:
		set_line_background_color(line_number, Color(0, 0, 0, 0))
		set_line_gutter_icon(line_number, 0, null)


## Insert or wrap some bbcode at the caret/selection.
func insert_bbcode(open_tag: String, close_tag: String = "") -> void:
	if close_tag == "":
		insert_text_at_caret(open_tag)
		grab_focus()
	else:
		var selected_text: String = get_selected_text()
		insert_text_at_caret("%s%s%s" % [open_tag, selected_text, close_tag])
		grab_focus()
		set_caret_column(get_caret_column() - close_tag.length())


## Insert text at current caret position. Moves caret down 1 line if not "=> END".
func insert_text_at_cursor(text_to_insert: String) -> void:
	if text_to_insert != "=> END":
		insert_text_at_caret(text_to_insert + "\n")
		set_caret_line(get_caret_line() + 1)
	else:
		insert_text_at_caret(text_to_insert)
	grab_focus()


## Toggle the selected lines as comments.
func toggle_comment() -> void:
	begin_complex_operation()

	var comment_delimiter: String = delimiter_comments[0]
	var is_first_line: bool = true
	var will_comment: bool = true
	var selections: Array = []
	var line_offsets: Dictionary = {}

	for caret_index in range(0, get_caret_count()):
		var from_line: int = get_caret_line(caret_index)
		var from_column: int = get_caret_column(caret_index)
		var to_line: int = get_caret_line(caret_index)
		var to_column: int = get_caret_column(caret_index)

		if has_selection(caret_index):
			from_line = get_selection_from_line(caret_index)
			to_line = get_selection_to_line(caret_index)
			from_column = get_selection_from_column(caret_index)
			to_column = get_selection_to_column(caret_index)

		selections.append({
			from_line = from_line,
			from_column = from_column,
			to_line = to_line,
			to_column = to_column
		})

		for line_number: int in range(from_line, to_line + 1):
			if line_offsets.has(line_number): continue

			var line_text: String = get_line(line_number)

			# The first line determines if we are commenting or uncommentingg
			if is_first_line:
				is_first_line = false
				will_comment = not line_text.strip_edges().begins_with(comment_delimiter)

			# Only comment/uncomment if the current line needs to
			if will_comment:
				set_line(line_number, comment_delimiter + line_text)
				line_offsets[line_number] = 1
			elif line_text.begins_with(comment_delimiter):
				set_line(line_number, line_text.substr(comment_delimiter.length()))
				line_offsets[line_number] = -1
			else:
				line_offsets[line_number] = 0

	for caret_index in range(0, get_caret_count()):
		var selection: Dictionary = selections[caret_index]
		select(
			selection.from_line,
			selection.from_column + line_offsets[selection.from_line],
			selection.to_line,
			selection.to_column + line_offsets[selection.to_line],
			caret_index
		)
		set_caret_column(selection.from_column + line_offsets[selection.from_line], false, caret_index)

	end_complex_operation()

	text_set.emit()
	text_changed.emit()


## Remove the current line.
func delete_current_line() -> void:
	var cursor: Vector2 = get_cursor()
	if get_line_count() == 1:
		select_all()
	elif cursor.y == 0:
		select(0, 0, 1, 0)
	else:
		select(cursor.y - 1, get_line_width(cursor.y - 1), cursor.y, get_line_width(cursor.y))
	delete_selection()
	text_changed.emit()


## Move the selected lines up or down.
func move_line(offset: int) -> void:
	offset = clamp(offset, -1, 1)

	var starting_scroll: float = scroll_vertical
	var cursor: Vector2 = get_cursor()
	var reselect: bool = false
	var from: int = cursor.y
	var to: int = cursor.y
	if has_selection():
		reselect = true
		from = get_selection_from_line()
		to = get_selection_to_line()

	var lines: PackedStringArray = text.split("\n")

	# Prevent the lines from being out of bounds
	if from + offset < 0 or to + offset >= lines.size(): return

	var target_from_index: int = from - 1 if offset == -1 else to + 1
	var target_to_index: int = to if offset == -1 else from
	var line_to_move: String = lines[target_from_index]
	lines.remove_at(target_from_index)
	lines.insert(target_to_index, line_to_move)

	text = "\n".join(lines)

	cursor.y += offset
	set_cursor(cursor)
	from += offset
	to += offset
	if reselect:
		select(from, 0, to, get_line_width(to))

	text_changed.emit()
	scroll_vertical = starting_scroll + offset


#endregion

#region Signals


func _on_project_settings_changed() -> void:
	_autoloads = {}

	# Add any actual autoloads
	var project = ConfigFile.new()
	project.load("res://project.godot")
	if project.has_section("autoload"):
		for autoload: String in project.get_section_keys("autoload"):
			if autoload != "DialogueManager":
				_autoloads[autoload] = project.get_value("autoload", autoload).substr(1)

	# Add project-defined classes if they contain static properties or methods
	var plugin_path: String = DMPlugin.get_plugin_path()
	if not plugin_path.is_empty():
		for script_info: Dictionary in ProjectSettings.get_global_class_list():
			if not script_info.path.begins_with(plugin_path):
				var script: Script = load(script_info.path)
				var static_match: RegExMatch = STATIC_CONTENT_REGEX.search(script.source_code)
				if static_match:
					_autoloads[script_info.class] = script_info.path


func _on_code_edit_symbol_validate(symbol: String) -> void:
	if symbol.begins_with("res://") and symbol.ends_with(".dialogue"):
		set_symbol_lookup_word_as_valid(true)
		return

	for title: String in get_titles():
		if symbol == title:
			set_symbol_lookup_word_as_valid(true)
			return

	# Check if it's a mutation line symbol
	var cursor: Vector2 = get_line_column_at_pos(get_local_mouse_pos())
	var line_text: String = get_line(cursor.y)
	var symbol_info: Dictionary = _resolve_mutation_symbol_at_position(line_text, cursor.x)
	if not symbol_info.is_empty() and symbol_info.get("symbol") == symbol:
		var script: Script = symbol_info.get("script")
		var member_name: String = symbol_info.get("member_name")
		if member_name == "class_name":
			set_symbol_lookup_word_as_valid(true)
			return
		else:
			var line_number: int = _find_definition_in_script(script, member_name)
			if line_number > 0:
				set_symbol_lookup_word_as_valid(true)
				return

	set_symbol_lookup_word_as_valid(false)


func _on_code_edit_symbol_lookup(symbol: String, line: int, column: int) -> void:
	if symbol.begins_with("res://") and symbol.ends_with(".dialogue"):
		external_file_requested.emit(symbol, "")
		return

	# Check if it's a title
	for title: String in get_titles():
		if symbol == title:
			go_to_title(symbol)
			return

	# Check if it's a mutation line symbol
	var line_text: String = get_line(line)
	var symbol_info: Dictionary = _resolve_mutation_symbol_at_position(line_text, column)
	if not symbol_info.is_empty() and symbol_info.get("symbol") == symbol:
		var script: Script = symbol_info.get("script")
		var member_name: String = symbol_info.get("member_name")
		if member_name == "class_name":
			EditorInterface.edit_script(script, 1, 0, true)
			EditorInterface.set_main_screen_editor.call_deferred("Script")
		else:
			var line_number: int = _find_definition_in_script(script, member_name)
			if line_number > 0:
				# Open the script in the editor
				EditorInterface.edit_script(script, line_number, 0, true)
				EditorInterface.set_main_screen_editor.call_deferred("Script")
				return


func _on_code_edit_text_changed() -> void:
	request_code_completion(true)
	_update_code_hint()


func _on_code_edit_text_set() -> void:
	queue_redraw()


func _on_code_edit_caret_changed() -> void:
	check_active_title()
	last_selected_text = get_selected_text()
	_update_code_hint()


func _on_code_edit_gutter_clicked(line: int, gutter: int) -> void:
	var line_errors = errors.filter(func(error): return error.line_number == line)
	if line_errors.size() > 0:
		error_clicked.emit(line)


#endregion

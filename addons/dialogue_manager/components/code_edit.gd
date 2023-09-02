@tool
extends CodeEdit


signal active_title_change(title: String)
signal error_clicked(line_number: int)
signal external_file_requested(path: String, title: String)


const DialogueSyntaxHighlighter = preload("res://addons/dialogue_manager/components/code_edit_syntax_highlighter.gd")


# A link back to the owner MainView
var main_view

# Theme overrides for syntax highlighting, etc
var theme_overrides: Dictionary:
	set(value):
		theme_overrides = value

		syntax_highlighter = DialogueSyntaxHighlighter.new()

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


func _ready() -> void:
	# Add error gutter
	add_gutter(0)
	set_gutter_type(0, TextEdit.GUTTER_TYPE_ICON)

	# Add comment delimiter
	if not has_comment_delimiter("#"):
		add_comment_delimiter("#", "", true)

	syntax_highlighter = DialogueSyntaxHighlighter.new()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		match event.as_text():
			"Ctrl+Equal", "Command+Equal":
				self.font_size += 1
				get_viewport().set_input_as_handled()
			"Ctrl+Minus", "Command+Minus":
				self.font_size -= 1
				get_viewport().set_input_as_handled()
			"Ctrl+0", "Command+0":
				self.font_size = theme_overrides.font_size
				get_viewport().set_input_as_handled()
			"Ctrl+K", "Command+K":
				toggle_comment()
				get_viewport().set_input_as_handled()
			"Alt+Up":
				move_line(-1)
				get_viewport().set_input_as_handled()
			"Alt+Down":
				move_line(1)
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

	var files: PackedStringArray = Array(data.files).filter(func(f): return f.get_extension() == "dialogue")
	return files.size() > 0


func _drop_data(at_position: Vector2, data) -> void:
	var replace_regex: RegEx = RegEx.create_from_string("[^a-zA-Z_0-9]+")

	var files: PackedStringArray = Array(data.files).filter(func(f): return f.get_extension() == "dialogue")
	for file in files:
		# Don't import the file into itself
		if file == main_view.current_file_path: continue

		var path = file.replace("res://", "").replace(".dialogue", "")
		# Find the first non-import line in the file to add our import
		var lines = text.split("\n")
		for i in range(0, lines.size()):
			if not lines[i].begins_with("import "):
				insert_line_at(i, "import \"%s\" as %s\n" % [file, replace_regex.sub(path, "_", true)])
				set_caret_line(i)
				break


func _request_code_completion(force: bool) -> void:
	var cursor: Vector2 = get_cursor()
	var current_line: String = get_line(cursor.y)

	if ("=> " in current_line or "=>< " in current_line) and (cursor.x > current_line.find("=>")):
		var prompt: String = current_line.split("=>")[1]
		if prompt.begins_with("< "):
			prompt = prompt.substr(2)
		else:
			prompt = prompt.substr(1)

		if "=> " in current_line:
			if matches_prompt(prompt, "end"):
				add_code_completion_option(CodeEdit.KIND_CLASS, "END", "END".substr(prompt.length()), theme_overrides.text_color, get_theme_icon("Stop", "EditorIcons"))
			if matches_prompt(prompt, "end!"):
				add_code_completion_option(CodeEdit.KIND_CLASS, "END!", "END!".substr(prompt.length()), theme_overrides.text_color, get_theme_icon("Stop", "EditorIcons"))

		# Get all titles, including those in imports
		var parser: DialogueManagerParser = DialogueManagerParser.new()
		parser.prepare(text, main_view.current_file_path, false)
		for title in parser.titles:
			if "/" in title:
				var bits = title.split("/")
				if matches_prompt(prompt, bits[0]) or matches_prompt(prompt, bits[1]):
					add_code_completion_option(CodeEdit.KIND_CLASS, title, title.substr(prompt.length()), theme_overrides.text_color, get_theme_icon("CombineLines", "EditorIcons"))
			elif matches_prompt(prompt, title):
				add_code_completion_option(CodeEdit.KIND_CLASS, title, title.substr(prompt.length()), theme_overrides.text_color, get_theme_icon("ArrowRight", "EditorIcons"))
		update_code_completion_options(true)
		parser.free()
		return

#	var last_character: String = current_line.substr(cursor.x - 1, 1)
	var name_so_far: String = current_line.strip_edges()
	if name_so_far != "" and name_so_far[0].to_upper() == name_so_far[0]:
		# Only show names starting with that character
		var names: PackedStringArray = get_character_names(name_so_far)
		if names.size() > 0:
			for name in names:
				add_code_completion_option(CodeEdit.KIND_CLASS, name + ": ", name.substr(name_so_far.length()) + ": ", theme_overrides.text_color, get_theme_icon("Sprite2D", "EditorIcons"))
			update_code_completion_options(true)
		else:
			cancel_code_completion()


func _filter_code_completion_candidates(candidates: Array) -> Array:
	# Not sure why but if this method isn't overridden then all completions are wrapped in quotes.
	return candidates


func _confirm_code_completion(replace: bool) -> void:
	var completion = get_code_completion_option(get_code_completion_selected_index())
	begin_complex_operation()
	# Delete any part of the text that we've already typed
	for i in range(0, completion.display_text.length() - completion.insert_text.length()):
		backspace()
	# Insert the whole match
	insert_text_at_caret(completion.display_text)
	end_complex_operation()

	# Close the autocomplete menu on the next tick
	call_deferred("cancel_code_completion")


### Helpers


# Get the current caret as a Vector2
func get_cursor() -> Vector2:
	return Vector2(get_caret_column(), get_caret_line())


# Set the caret from a Vector2
func set_cursor(from_cursor: Vector2) -> void:
	set_caret_line(from_cursor.y)
	set_caret_column(from_cursor.x)


# Check if a prompt is the start of a string without actually being that string
func matches_prompt(prompt: String, matcher: String) -> bool:
	return prompt.length() < matcher.length() and matcher.to_lower().begins_with(prompt.to_lower())


## Get a list of titles from the current text
func get_titles() -> PackedStringArray:
	var titles = PackedStringArray([])
	var lines = text.split("\n")
	for line in lines:
		if line.begins_with("~ "):
			titles.append(line.substr(2).strip_edges())
	return titles


## Work out what the next title above the current line is
func check_active_title() -> void:
	var line_number = get_caret_line()
	var lines = text.split("\n")
	# Look at each line above this one to find the next title line
	for i in range(line_number, -1, -1):
		if lines[i].begins_with("~ "):
			emit_signal("active_title_change", lines[i].replace("~ ", ""))
			return

	emit_signal("active_title_change", "0")


# Move the caret line to match a given title
func go_to_title(title: String) -> void:
	var lines = text.split("\n")
	for i in range(0, lines.size()):
		if lines[i].strip_edges() == "~ " + title:
			set_caret_line(i)
			center_viewport_to_caret()


func get_character_names(beginning_with: String) -> PackedStringArray:
	var names: PackedStringArray = []
	var lines = text.split("\n")
	for line in lines:
		if ": " in line:
			var name: String = line.split(": ")[0].strip_edges()
			if not name in names and matches_prompt(beginning_with, name):
				names.append(name)
	return names


# Mark a line as an error or not
func mark_line_as_error(line_number: int, is_error: bool) -> void:
	if is_error:
		set_line_background_color(line_number, theme_overrides.error_line_color)
		set_line_gutter_icon(line_number, 0, get_theme_icon("StatusError", "EditorIcons"))
	else:
		set_line_background_color(line_number, theme_overrides.background_color)
		set_line_gutter_icon(line_number, 0, null)


# Insert or wrap some bbcode at the caret/selection
func insert_bbcode(open_tag: String, close_tag: String = "") -> void:
	if close_tag == "":
		insert_text_at_caret(open_tag)
		grab_focus()
	else:
		var selected_text = get_selected_text()
		insert_text_at_caret("%s%s%s" % [open_tag, selected_text, close_tag])
		grab_focus()
		set_caret_column(get_caret_column() - close_tag.length())

# Insert text at current caret position
# Move Caret down 1 line if not => END
func insert_text(text: String) -> void:
	if text != "=> END":
		insert_text_at_caret(text+"\n")
		set_caret_line(get_caret_line()+1)
	else:
		insert_text_at_caret(text)
	grab_focus()


# Toggle the selected lines as comments
func toggle_comment() -> void:
	# Starting complex operation so that the entire toggle comment can be undone in a single step
	begin_complex_operation()

	var caret_count: int = get_caret_count()
	var caret_offsets: Dictionary = {}

	for caret_index in caret_count:
		var caret_line: int = get_caret_line(caret_index)
		var from: int = caret_line
		var to: int = caret_line

		if has_selection(caret_index):
			from = get_selection_from_line(caret_index)
			to = get_selection_to_line(caret_index)

		for line in range(from, to + 1):
			if line not in caret_offsets:
				caret_offsets[line] = 0

			var line_text: String = get_line(line)
			var comment_delimiter: String = delimiter_comments[0]
			var is_line_commented: bool = line_text.begins_with(comment_delimiter)
			set_line(line, line_text.substr(comment_delimiter.length()) if is_line_commented else comment_delimiter + line_text)
			caret_offsets[line] += (-1 if is_line_commented else 1) * comment_delimiter.length()

		emit_signal("lines_edited_from", from, to)

	# Readjust carets and selection positions after all carets effect have been calculated
	# Tried making it in the above loop, but that causes a weird behaviour if two carets are on the same line (first caret will move, but not the second one)
	for caret_index in caret_count:
		if has_selection(caret_index):
			var from: int = get_selection_from_line(caret_index)
			var to: int = get_selection_to_line(caret_index)
			select(from, get_selection_from_column(caret_index) + caret_offsets[from], to, get_selection_to_column(caret_index) + caret_offsets[to], caret_index)

		set_caret_column(get_caret_column(caret_index) + caret_offsets[get_caret_line(caret_index)], true, caret_index)

	end_complex_operation()

	emit_signal("text_set")
	emit_signal("text_changed")


# Move the selected lines up or down
func move_line(offset: int) -> void:
	offset = clamp(offset, -1, 1)

	var cursor = get_cursor()
	var reselect: bool = false
	var from: int = cursor.y
	var to: int = cursor.y
	if has_selection():
		reselect = true
		from = get_selection_from_line()
		to = get_selection_to_line()

	var lines := text.split("\n")

	# We can't move the lines out of bounds
	if from + offset < 0 or to + offset >= lines.size(): return

	var target_from_index = from - 1 if offset == -1 else to + 1
	var target_to_index = to if offset == -1 else from
	var line_to_move = lines[target_from_index]
	lines.remove_at(target_from_index)
	lines.insert(target_to_index, line_to_move)

	text = "\n".join(lines)

	cursor.y += offset
	from += offset
	to += offset
	if reselect:
		select(from, 0, to, get_line_width(to))
	set_cursor(cursor)
	emit_signal("text_changed")


### Signals


func _on_code_edit_symbol_validate(symbol: String) -> void:
	if symbol.begins_with("res://") and symbol.ends_with(".dialogue"):
		set_symbol_lookup_word_as_valid(true)
		return

	for title in get_titles():
		if symbol == title:
			set_symbol_lookup_word_as_valid(true)
			return
	set_symbol_lookup_word_as_valid(false)


func _on_code_edit_symbol_lookup(symbol: String, line: int, column: int) -> void:
	if symbol.begins_with("res://") and symbol.ends_with(".dialogue"):
		emit_signal("external_file_requested", symbol, "")
	else:
		go_to_title(symbol)


func _on_code_edit_text_changed() -> void:
	request_code_completion(true)


func _on_code_edit_text_set() -> void:
	queue_redraw()


func _on_code_edit_caret_changed() -> void:
	check_active_title()
	last_selected_text = get_selected_text()


func _on_code_edit_gutter_clicked(line: int, gutter: int) -> void:
	var line_errors = errors.filter(func(error): return error.line_number == line)
	if line_errors.size() > 0:
		emit_signal("error_clicked", line)

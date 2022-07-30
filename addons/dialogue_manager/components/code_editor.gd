tool
extends TextEdit


const ChooseTitleDialog = preload("res://addons/dialogue_manager/views/choose_title_dialog.gd")


signal active_title_changed(title)


export var _choose_title_dialog := NodePath()

onready var choose_title_dialog: ChooseTitleDialog = get_node(_choose_title_dialog)

var active_title_id: int = 0
var current_goto_title: String = ""
var current_goto_line: int = -1
var last_selection_text: String = ""

var GOTO_ITEM_INDEX = -1
var CREATE_ITEM_INDEX = -1
var PICK_ITEM_INDEX = -1


func _ready() -> void:
	# Set up popup menu
	var menu = get_menu()
	menu.connect("about_to_show", self, "_on_menu_about_to_show")
	menu.connect("index_pressed", self, "_on_menu_index_pressed")
	menu.add_separator()
	
	menu.add_item("Go to " + current_goto_title, 101,  KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_G)
	GOTO_ITEM_INDEX = menu.get_item_index(101)
	
	menu.add_item("Create " + current_goto_title, 102, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_C)
	CREATE_ITEM_INDEX = menu.get_item_index(102)
	
	menu.add_icon_item(get_icon("Search", "EditorIcons"), "Choose a jump target...", 103,  KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_SPACE)
	PICK_ITEM_INDEX = menu.get_item_index(103)
	
	# Set up choose title dialog
	choose_title_dialog.connect("title_chosen", self, "_on_title_chosen")
	
	# Colors
	var title_color = get_color("accent_color", "Editor")
	var comment_color = get_color("font_color", "Editor")
	comment_color.a = 0.5
	var condition_color = get_color("error_color", "Editor")
	var value_color = get_color("warning_color", "Editor")
	var mutation_color = get_color("success_color", "Editor")
	var goto_color = get_color("accent_color", "Editor")
	goto_color.a = 0.7
	var dialogue_color = get_color("mono_color", "Editor")
	
	# Title
	add_color_region("~", "~", title_color, true)
	
	# Comments
	add_color_region("#", "##", comment_color, true)
	
	# Conditions
	add_keyword_color("if", condition_color)
	add_keyword_color("elif", condition_color)
	add_keyword_color("else", condition_color)
	add_keyword_color("endif", condition_color)
	add_keyword_color("in", condition_color)
	add_keyword_color("and", condition_color)
	add_keyword_color("or", condition_color)
	add_keyword_color("not", condition_color)
	
	# Values
	add_keyword_color("true", value_color)
	add_keyword_color("false", value_color)
	add_color_override("number_color", value_color)
	add_color_region("\"", "\"", value_color)
	
	# Mutations
	add_keyword_color("do", mutation_color)
	add_keyword_color("set", mutation_color)
	add_color_override("function_color", mutation_color)
	
	# Jumps
	add_color_region("=>", "<=", goto_color, true)
	
	# Dialogue
	add_color_region(": ", "::", dialogue_color, true)
	
	# Errors
	add_color_override("bookmark_color", Color("ff5555"))
	
	# General UI
	add_constant_override("line_spacing", 10)
	add_color_override("symbol_color", get_color("font_color", "Editor"))
	add_color_override("font_color", get_color("font_color", "Editor"))
	add_color_override("background_color", get_color("base_color", "Editor"))
	add_color_override("current_line_color", get_color("base_color", "Editor").lightened(0.1))
	add_font_override("font", get_font("source", "EditorFonts"))


func _gui_input(event):
	if not event is InputEventKey: return
	if not event.is_pressed(): return
	
	match event.as_text():
		"Control+Shift+G":
			go_to_title(current_goto_title)
		"Control+Shift+C":
			create_title(current_goto_title)
		"Control+Shift+Space":
			choose_title_dialog.choose_a_title(get_titles())
		"Control+K":
			toggle_comment()
		"Alt+Up":
			move_line(-1)
		"Alt+Down":
			move_line(1)


func get_cursor() -> Vector2:
	return Vector2(cursor_get_column(), cursor_get_line())


func set_cursor(cursor: Vector2) -> void:
	cursor_set_line(cursor.y, true)
	cursor_set_column(cursor.x, true)


func toggle_comment() -> void:
	var cursor := get_cursor()
	var from: int = cursor.y
	var to: int = cursor.y
	if is_selection_active():
		from = get_selection_from_line()
		to = get_selection_to_line()
	
	var lines := text.split("\n")
	var will_comment := not lines[from].begins_with("#")
	for i in range(from, to + 1):
		lines[i] = "#" + lines[i] if will_comment else lines[i].substr(1)
	
	text = lines.join("\n")
	select(from, 0, to, get_line_width(to))
	set_cursor(cursor)


func move_line(offset: int) -> void:
	offset = clamp(offset, -1, 1)
	
	var cursor = get_cursor()
	var reselect: bool = false
	var from: int = cursor.y
	var to: int = cursor.y
	
	if is_selection_active():
		reselect = true
		from = get_selection_from_line()
		to = get_selection_to_line()
	
	var lines := text.split("\n")
	
	# We can't move the lines out of bounds
	if from + offset < 0 or to + offset >= lines.size(): return
	
	var target_from_index = from - 1 if offset == -1 else to + 1
	var target_to_index = to if offset == -1 else from
	var line_to_move = lines[target_from_index]
	lines.remove(target_from_index)
	lines.insert(target_to_index, line_to_move)
	
	text = lines.join("\n")
	
	cursor.y += offset
	from += offset
	to += offset
	if reselect:
		select(from, 0, to, get_line_width(to))
	set_cursor(cursor)
	

func insert_bbcode(open_tag: String, close_tag: String = "") -> void:
	if close_tag == "":
		insert_text_at_cursor(open_tag)
		grab_focus()
	else:
		var selected_text = get_selection_text()
		insert_text_at_cursor("%s%s%s" % [open_tag, selected_text, close_tag])
		grab_focus()
		cursor_set_column(cursor_get_column() - close_tag.length())


func get_titles() -> Array:
	var titles = PoolStringArray([])
	var lines = text.split("\n")
	for line in lines:
		if line.begins_with("~ "):
			titles.append(line.substr(2).strip_edges())
	return titles


func go_to_title(title: String) -> void:
	var lines = text.split("\n")
	for i in range(0, lines.size()):
		if lines[i].strip_edges() == "~ " + title:
			cursor_set_line(i)
			center_viewport_to_cursor()


func create_title(title: String) -> void:
	text = text + "\n\n~ " + title + "\n\nCharacter: This is a new node."
	emit_signal("text_changed")
	cursor_set_line(get_line_count() - 1)


func check_active_title() -> void:
	var line_number = cursor_get_line()
	var lines = text.split("\n")
	# Look at each line above this one to find the next title line
	for i in range(line_number, -1, -1):
		if lines[i].begins_with("~ "):
			emit_signal("active_title_changed", lines[i].replace("~ ", ""))
			active_title_id = i
			break


func update_current_goto_title() -> void:
	var line_number = cursor_get_line()
	var current_line = get_line(line_number)
	
	var next_goto_title = ""
	
	# If we are on a goto line then make a note of the title and the line
	# of the target title (if it exists)
	if "=> " in current_line:
		next_goto_title = current_line.substr(current_line.find("=> ") + 3).strip_edges()
	elif "=>< " in current_line:
		next_goto_title = current_line.substr(current_line.find("=>< ") + 4).strip_edges()
	
	current_goto_title = next_goto_title
	
	if next_goto_title != "":
		# Check if title exists
		current_goto_line = -1
		var lines = text.split("\n")
		for i in range(0, lines.size()):
			if lines[i].strip_edges() == "~ " + next_goto_title:
				current_goto_line = i
				break
	
	# Otherwise just clear it out
	else:
		current_goto_title = ""
		current_goto_line = -1


### Signals


func _on_menu_about_to_show():
	update_current_goto_title()
	
	# Update our special menu items based on what the goto details are
	var menu = get_menu()
	if current_goto_title != "":
		# END and END! are special titles which end the conversation. They never point
		# to an actual title
		if current_goto_title in ["END", "END!"]:
			menu.set_item_text(CREATE_ITEM_INDEX, "Create node")
			menu.set_item_disabled(CREATE_ITEM_INDEX, true)
			menu.set_item_text(GOTO_ITEM_INDEX, "Jump to node")
			menu.set_item_disabled(GOTO_ITEM_INDEX, true)
		# Otherwise we can either go to the title or create it if it doesn't
		# exist.
		else:
			menu.set_item_text(GOTO_ITEM_INDEX, "Jump to " + current_goto_title)
			menu.set_item_disabled(GOTO_ITEM_INDEX, current_goto_line == -1)
			menu.set_item_text(CREATE_ITEM_INDEX, "Create " + current_goto_title)
			menu.set_item_disabled(CREATE_ITEM_INDEX, current_goto_line > -1)
		menu.set_item_disabled(PICK_ITEM_INDEX, false)
		
	# If we aren't on a goto line then just disable the options
	else:
		menu.set_item_text(GOTO_ITEM_INDEX, "Jump to node")
		menu.set_item_disabled(GOTO_ITEM_INDEX, true)
		menu.set_item_text(CREATE_ITEM_INDEX, "Create node")
		menu.set_item_disabled(CREATE_ITEM_INDEX, true)
		menu.set_item_disabled(PICK_ITEM_INDEX, true)


func _on_menu_index_pressed(index):
	match index:
		GOTO_ITEM_INDEX:
			go_to_title(current_goto_title)
		
		CREATE_ITEM_INDEX:
			create_title(current_goto_title)
		
		PICK_ITEM_INDEX:
			choose_title_dialog.choose_a_title(get_titles())


func _on_title_chosen(title):
	var cursor_line = cursor_get_line()
	var line: String = get_line(cursor_line)
	
	if "=> " in line:
		line = line.substr(0, line.find("=> ") + 2)
	elif "=>< " in line:
		line = line.substr(0, line.find("=>< ") + 3)
	
	set_line(cursor_line, line + " " + title)
	current_goto_title = title
	
	cursor_set_line(cursor_line)


func _on_CodeEditor_cursor_changed():
	check_active_title()
	update_current_goto_title()
	
	last_selection_text = get_selection_text()


func _on_CodeEditor_text_changed():
	check_active_title()
	update_current_goto_title()

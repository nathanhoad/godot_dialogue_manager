@tool
extends Control


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueParser = preload("res://addons/dialogue_manager/components/parser.gd")
const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")


@onready var parse_timer := $ParseTimer

# Dialogs
@onready var new_dialog: FileDialog = $NewDialog
@onready var open_dialog: FileDialog = $OpenDialog
@onready var export_dialog: FileDialog = $ExportDialog
@onready var import_dialog: FileDialog = $ImportDialog
@onready var errors_dialog: AcceptDialog = $ErrorsDialog
@onready var settings_dialog: AcceptDialog = $SettingsDialog
@onready var settings_view := $SettingsDialog/SettingsView
@onready var build_error_dialog: AcceptDialog = $BuildErrorDialog

# Toolbar
@onready var current_file_button: Button = %CurrentFileButton
@onready var new_button: Button = %NewButton
@onready var open_button: MenuButton = %OpenButton
@onready var test_button: Button = %TestButton
@onready var search_button: Button = %SearchButton
@onready var insert_button: MenuButton = %InsertButton
@onready var translations_button: MenuButton = %TranslationsButton
@onready var settings_button: Button = %SettingsButton
@onready var docs_button: Button = %DocsButton
@onready var version_label: Label = %VersionLabel
@onready var update_button: Button = %UpdateButton

@onready var search_and_replace := %SearchAndReplace

# Code editor
@onready var title_list := %TitleList
@onready var code_edit := %CodeEdit
@onready var errors_panel := %ErrorsPanel

# The Dialogue Manager plugin
var editor_plugin: EditorPlugin

# The currently open file
var current_file_path: String = "":
	set(next_current_file_path):
		current_file_path = next_current_file_path
		current_file_button.text = get_nice_file(current_file_path)
		if current_file_path == "":
			current_file_button.disabled = true
			current_file_button.text = "No file open"
			test_button.disabled = true
			search_button.disabled = true
			insert_button.disabled = true
			translations_button.disabled = true
			title_list.hide()
			code_edit.hide()
		else:
			current_file_button.disabled = false
			test_button.disabled = false
			search_button.disabled = false
			insert_button.disabled = false
			translations_button.disabled = false
			title_list.show()
			code_edit.show()
	get:
		return current_file_path

# Keep a copy of the text at the last save
var pristine_text: String = ""

# A reference to the color palette
var colors: Dictionary = {}


func _ready() -> void:
	apply_theme()
	
	# Start with nothing open
	self.current_file_path = ""
	
	# Set up the update checker
	version_label.text = "v%s" % update_button.get_version()
	update_button.editor_plugin = editor_plugin
	update_button.on_before_refresh = func on_before_refresh():
		# Save everything
		DialogueSettings.set_user_value("just_refreshed", {
			current_file_path = current_file_path,
			current_file_content = code_edit.text
		})
		return true
	
	# Did we just load from an addon version refresh?
	var just_refreshed = DialogueSettings.get_user_value("just_refreshed", null)
	if just_refreshed != null:
		DialogueSettings.set_user_value("just_refreshed", null)
		call_deferred("load_from_version_refresh", just_refreshed)
	
	# Hook up the search toolbar
	search_and_replace.code_edit = code_edit
	
	# Connect menu buttons
	insert_button.get_popup().id_pressed.connect(_on_insert_button_menu_id_pressed)
	translations_button.get_popup().id_pressed.connect(_on_translations_button_menu_id_pressed)
	
	code_edit.main_view = self
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if DialogueSettings.get_setting("wrap_lines", false) else TextEdit.LINE_WRAPPING_NONE


func apply_changes() -> void:
	save_file()


# Load back to the previous buffer regardless of if it was actually saved
func load_from_version_refresh(just_refreshed: Dictionary) -> void:
	editor_plugin.get_editor_interface().edit_resource(load(just_refreshed.current_file_path))
	pristine_text = code_edit.text
	code_edit.text = just_refreshed.current_file_content
	_on_code_edit_text_changed()


# Open a dialogue resource for editing
func open_resource(resource: Resource) -> void:
	open_file(resource.resource_path)


func open_file(path: String) -> void:
	# It's the same resource so do nothing
	if current_file_path == path: return
	
	# Save the current resource
	save_file()
	
	# Create the file if it doesn't exist
	var file = File.new()
	if not file.file_exists(path):
		file.open(path, File.WRITE)
		file.store_string("\n".join([
			"~ this_is_a_node_title",
			"",
			"Nathan: [[Hi|Hello|Howdy]], this is some dialogue.",
			"Nathan: Here are some choices.",
			"- First one",
				"\tNathan: You picked the first one.",
			"- Second one",
				"\tNathan: You picked the second one.",
			"- Start again => this_is_a_node_title",
			"- End the conversation => END",
			"Nathan: For more information see the online documentation."
		]))
		file.close()
		editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	
	# Open the new resource
	self.current_file_path = path
	if current_file_path != "":
		file = File.new()
		file.open(current_file_path, File.READ)
		var text = file.get_as_text()
		file.close()
		
		code_edit.text = text
		code_edit.errors = []
		code_edit.clear_undo_history()
		code_edit.set_cursor(DialogueSettings.get_caret(current_file_path))
		code_edit.grab_focus()
		
		pristine_text = text
		
		_on_code_edit_text_changed()
		
		DialogueSettings.add_recent_file(path)
		build_open_menu()
	
	errors_panel.errors = []
	code_edit.errors = []


# Save the current file
func save_file() -> void:
	# Don't bother saving if there is nothing to save
	if pristine_text == code_edit.text: return
	if current_file_path == "": return
	
	# Save the current resource
	var file = File.new()
	file.open(current_file_path, File.WRITE)
	file.store_string(code_edit.text)
	file.close()
	
	pristine_text = code_edit.text
	update_current_file_button()
	
	# Make sure we reimport/recompile the changes
	editor_plugin.get_editor_interface().get_resource_filesystem().scan()


# Apply theme colors and icons to the UI
func apply_theme() -> void:
	if is_instance_valid(editor_plugin) and is_instance_valid(code_edit):
		var editor_settings = editor_plugin.get_editor_interface().get_editor_settings()
		colors = {
			background = editor_settings.get_setting("text_editor/theme/highlighting/background_color"),
			current_line = editor_settings.get_setting("text_editor/theme/highlighting/current_line_color"),
			error_line = editor_settings.get_setting("text_editor/theme/highlighting/mark_color"),
		
			titles = editor_settings.get_setting("text_editor/theme/highlighting/control_flow_keyword_color"),
			text = editor_settings.get_setting("text_editor/theme/highlighting/text_color"),
			conditions = editor_settings.get_setting("text_editor/theme/highlighting/keyword_color"),
			mutations = editor_settings.get_setting("text_editor/theme/highlighting/function_color"),
			members = editor_settings.get_setting("text_editor/theme/highlighting/member_variable_color"),
			strings = editor_settings.get_setting("text_editor/theme/highlighting/string_color"),
			numbers = editor_settings.get_setting("text_editor/theme/highlighting/number_color"),
			symbols = editor_settings.get_setting("text_editor/theme/highlighting/symbol_color"),
			comments = editor_settings.get_setting("text_editor/theme/highlighting/comment_color"),
			jumps = Color(editor_settings.get_setting("text_editor/theme/highlighting/control_flow_keyword_color"), 0.7),
		}
		code_edit.colors = colors
	
		current_file_button.icon = get_theme_icon("Filesystem", "EditorIcons")
		new_button.icon = get_theme_icon("New", "EditorIcons")
		new_button.tooltip_text = "Start a new file"
		open_button.icon = get_theme_icon("Load", "EditorIcons")
		open_button.tooltip_text = "Open a file"
		test_button.icon = get_theme_icon("PlayScene", "EditorIcons")
		test_button.tooltip_text = "Test dialogue"
		search_button.icon = get_theme_icon("Search", "EditorIcons")
		search_button.tooltip_text = "Search for text"
		insert_button.icon = get_theme_icon("RichTextEffect", "EditorIcons")
		insert_button.text = "Insert"
		translations_button.icon = get_theme_icon("Translation", "EditorIcons")
		translations_button.text = "Translations"
		settings_button.icon = get_theme_icon("Tools", "EditorIcons")
		settings_button.tooltip_text = "Settings"
		docs_button.icon = get_theme_icon("Help", "EditorIcons")
		docs_button.text = "Docs"
		
		update_button.apply_theme()
		
		# Set up the effect menu
		var popup: PopupMenu = insert_button.get_popup()
		popup.clear()
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "Wave BBCode", 0)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "Shake BBCode", 1)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("Time", "EditorIcons"), "Typing pause", 3)
		popup.add_icon_item(get_theme_icon("ViewportSpeed", "EditorIcons"), "Typing speed change", 4)
		popup.add_icon_item(get_theme_icon("DebugNext", "EditorIcons"), "Auto advance", 5)
		
		# Set up the translations menu
		popup = translations_button.get_popup()
		popup.clear()
		popup.add_icon_item(get_theme_icon("Translation", "EditorIcons"), "Generate line IDs", 0)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("FileList", "EditorIcons"), "Save to CSV...", 2)
		popup.add_icon_item(get_theme_icon("AssetLib", "EditorIcons"), "Import changes from CSV..." , 3)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("FileList", "EditorIcons"), "Save to PO...", 5)


### Helpers


# Refresh the open menu with the latest files
func build_open_menu() -> void:
	var menu = open_button.get_popup()
	menu.clear()
	menu.add_icon_item(get_theme_icon("Load", "EditorIcons"), "Open...")
	menu.add_separator()
	
	var recent_files = DialogueSettings.get_recent_files()
	if recent_files.size() == 0:
		menu.add_item("No recent files")
		menu.set_item_disabled(2, true)
	else:
		for path in recent_files:
			menu.add_icon_item(get_theme_icon("File", "EditorIcons"), path)
			
	menu.add_separator()
	menu.add_item("Clear recent files")
	if menu.index_pressed.is_connected(_on_open_menu_index_pressed):
		menu.index_pressed.disconnect(_on_open_menu_index_pressed)
	menu.index_pressed.connect(_on_open_menu_index_pressed)


# Show the current file name and a saved indicator
func update_current_file_button() -> void:
	var unsaved_indicator: String = "*" if pristine_text != code_edit.text else ""
	current_file_button.text = get_nice_file(current_file_path) + unsaved_indicator


# Shorten a path to just its parent folder and filename
func get_nice_file(file: String) -> String:
	var bits = file.replace("res://", "").split("/")
	if bits.size() == 1:
		return bits[0]
	else:
		return "%s/%s" % [bits[bits.size() - 2], bits[bits.size() - 1]]


# Get the last place a CSV, etc was exported
func get_last_export_path(extension: String) -> String:
	var filename = current_file_path.get_file().replace(".dialogue", "." + extension)
	return DialogueSettings.get_user_value("last_export_path", current_file_path.get_base_dir()) + "/" + filename


# Check the current text for errors
func parse() -> void:
	# Skip if nothing to parse
	if current_file_path == "": return
	
	var parser = DialogueParser.new()
	var errors: Array[Dictionary] = []
	if parser.parse(code_edit.text) != OK:
		errors = parser.get_errors()
	code_edit.errors = errors
	errors_panel.errors = errors


func show_build_error_dialog() -> void:
	build_error_dialog.popup_centered()


# Generate translation line IDs for any line that doesn't already have one
func generate_translations_keys() -> void:
	randomize()
	seed(Time.get_unix_time_from_system())
	
	var parser = DialogueParser.new()
	
	var cursor: Vector2 = code_edit.get_cursor()
	var lines: PackedStringArray = code_edit.text.split("\n")
	
	var key_regex = RegEx.new()
	key_regex.compile("\\[ID:(?<key>.*?)\\]")
	
	# Make list of known keys
	var known_keys = {}
	for i in range(0, lines.size()):
		var line = lines[i]
		var found = key_regex.search(line)
		if found:
			var text = ""
			var l = line.replace(found.strings[0], "").strip_edges().strip_edges()
			if l.begins_with("- "):
				text = parser.extract_response_prompt(l)
			elif ":" in l:
				text = l.split(":")[1]
			else:
				text = l
			known_keys[found.strings[found.names.get("key")]] = text
	
	# Add in any that are missing
	for i in lines.size():
		var line = lines[i]
		var l = line.strip_edges()
		
		if parser.is_line_empty(l): continue
		if parser.is_condition_line(l, true): continue
		if parser.is_title_line(l): continue
		if parser.is_mutation_line(l): continue
		if parser.is_goto_line(l): continue
		
		if "[ID:" in line: continue
		
		var key = "t" + str(randi() % 1000000).sha1_text().substr(0, 10)
		while key in known_keys:
			key = "t" + str(randi() % 1000000).sha1_text().substr(0, 10)
		
		var text = ""
		if l.begins_with("- "):
			text = parser.extract_response_prompt(l)
		else:
			text = l.substr(l.find(":") + 1)
		
		lines[i] = line.replace(text, text + " [ID:%s]" % key)
		known_keys[key] = text
	
	code_edit.text = "\n".join(lines)
	code_edit.set_cursor(cursor)
	_on_code_edit_text_changed()
	
	parser.free()


# Export dialogue and responses to CSV
func export_translations_to_csv(path: String) -> void:
	var file = File.new()
	
	# If the file exists, open it first and work out which keys are already in it
	var existing_csv = {}
	var commas = []
	if file.file_exists(path):
		file.open(path, File.READ)
		var is_first_line = true
		var line: Array
		while !file.eof_reached():
			line = file.get_csv_line()
			if is_first_line:
				is_first_line = false
				for i in range(2, line.size()):
					commas.append("")
			# Make sure the line isn't empty before adding it
			if line.size() > 0 and line[0].strip_edges() != "":
				existing_csv[line[0]] = line
		file.close()
		
	# Start a new file
	file.open(path, File.WRITE)
	
	if not file.file_exists(path):
		file.store_csv_line(["keys", "en"])

	# Write our translations to file
	var known_keys := PackedStringArray([])
	
	var parser = DialogueParser.new()
	parser.parse(code_edit.text)
	var dialogue = parser.get_data().lines
	parser.free()
	
	# Make a list of stuff that needs to go into the file
	var lines_to_save = []
	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)
		
		if not line.type in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]: continue
		if line.translation_key in known_keys: continue
		
		known_keys.append(line.translation_key)
		
		if existing_csv.has(line.translation_key):
			var existing_line = existing_csv.get(line.translation_key)
			existing_line[1] = line.text
			lines_to_save.append(existing_line)
			existing_csv.erase(line.translation_key)
		else:
			lines_to_save.append(PackedStringArray([line.translation_key, line.text] + commas))
	
	# Store lines in the file, starting with anything that already exists that hasn't been touched
	for line in existing_csv.values():
		file.store_csv_line(line)
	for line in lines_to_save:
		file.store_csv_line(line)
	
	file.close()
	
	editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	editor_plugin.get_editor_interface().get_file_system_dock().navigate_to_path(path)


# Import changes back from an exported CSV by matching translation keys
func import_translations_from_csv(path: String) -> void:
	var cursor: Vector2 = code_edit.get_cursor()

	# Open the CSV file and build a dictionary of the known keys
	var file := File.new()
	
	if not file.file_exists(path): return

	var keys: Dictionary = {}
	file.open(path, File.READ)
	var csv_line: Array
	while !file.eof_reached():
		csv_line = file.get_csv_line()
		if csv_line.size() > 1:
			keys[csv_line[0]] = csv_line[1]
	file.close()
	
	var parser = DialogueParser.new()
	
	# Now look over each line in the dialogue and replace the content for matched keys
	var lines: PackedStringArray = code_edit.text.split("\n")
	var start_index: int = 0
	var end_index: int = 0
	for i in range(0, lines.size()):
		var line: String = lines[i]
		var translation_key: String = parser.extract_translation(line)
		if keys.has(translation_key):
			if parser.is_dialogue_line(line):
				start_index = 0
				# See if we need to skip over a character name
				line = line.replace("\\:", "!ESCAPED_COLON!")
				if ": " in line:
					start_index = line.find(": ") + 2
				lines[i] = (line.substr(0, start_index) + keys.get(translation_key) + " [ID:" + translation_key + "]").replace("!ESCAPED_COLON!", ":")
				
			elif parser.is_response_line(line):
				start_index = line.find("- ") + 2
				# See if we need to skip over a character name
				line = line.replace("\\:", "!ESCAPED_COLON!")
				if ": " in line:
					start_index = line.find(": ") + 2
				end_index = line.length()
				if " =>" in line:
					end_index = line.find(" =>")
				if " [if " in line:
					end_index = line.find(" [if ")
				lines[i] = (line.substr(0, start_index) + keys.get(translation_key) + " [ID:" + translation_key + "]" + line.substr(end_index)).replace("!ESCAPED_COLON!", ":")
	
	code_edit.text = "\n".join(lines)
	code_edit.set_cursor(cursor)
	
	parser.free()


# Export dialogue and response text to PO format
func export_translations_to_po(path: String) -> void:
	var id_str: Dictionary = {}
	
	var parser = DialogueParser.new()
	parser.parse(code_edit.text)
	var dialogue = parser.get_data().lines
	parser.free()

	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)

		if not line.type in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]: continue
		if line.translation_key in id_str: continue

		id_str[line.translation_key] = line.text

	var file = File.new()

	# If the file exists, keep content except for known entries.
	var existing_po: String = ""
	var already_existing_keys := PackedStringArray([])
	if file.file_exists(path):
		file.open(path, File.READ)
		var line: String
		while !file.eof_reached():
			line = file.get_line().strip_edges()

			if line.begins_with("msgid"): # Extract msgid
				var msgid = line.trim_prefix("msgid \"").trim_suffix("\"").c_unescape()
				existing_po += line + "\n"
				line = file.get_line().strip_edges()
				while not line.begins_with("msgstr") and not file.eof_reached():
					if line.begins_with("\""):
						msgid += line.trim_prefix("\"").trim_suffix("\"").c_unescape()
					existing_po += line + "\n"
					line = file.get_line().strip_edges()

				already_existing_keys.append(msgid)
				if msgid in id_str:
					existing_po += _generate_po_line("msgstr", id_str[msgid])
					# skip old msgstr
					while not file.eof_reached() and not line.is_empty() and (line.begins_with("msgstr") or line.begins_with("\"")):
						line = file.get_line().strip_edges()
					existing_po += line + "\n"
				else: # keep unknown msgstr
					existing_po += line + "\n"
					while not file.eof_reached() and not line.is_empty() and (line.begins_with("msgstr") or line.begins_with("\"")):
						line = file.get_line().strip_edges()
						existing_po += line + "\n"
			else: # keep old lines
				existing_po += line + "\n"
		file.close()

	# Godot requires the config in the PO regardless of whether it constains anything relevant.
	if !("" in already_existing_keys):
		existing_po += _generate_po_line("msgid", "")
		existing_po += "msgstr \"\"\n\"Content-Type: text/plain; charset=UTF-8\\n\"" + "\n" + "\n"

	for key in id_str:
		if !(key in already_existing_keys):
			existing_po += _generate_po_line("msgid", key)
			existing_po += _generate_po_line("msgstr", id_str[key]) + "\n"

	existing_po = existing_po.trim_suffix("\n")

	# Start a new file
	file.open(path, File.WRITE)
	file.store_string(existing_po)
	file.close()

	editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	editor_plugin.get_editor_interface().get_file_system_dock().navigate_to_path(path)


# type is supposed to be either msgid or msgstr
func _generate_po_line(type: String, line) -> String:
	var result: String
	if "\n" in line: # multiline
		result += type + " \"\"\n"
		var lines: PackedStringArray = line.split("\n")
		for i in len(lines):
			if i != len(lines) - 1:
				# c_espace also escapes "?" and "'". msgfmt doesn't like that.
				result += "\"" + lines[i].c_escape().replace("\\?", "?").replace("\\'", "'") + "\\n\"\n"
			else:
				result += "\"" + lines[i].c_escape().replace("\\?", "?").replace("\\'", "'") + "\"\n"
	else: # singleline
		result += type + " \"" + line.c_escape().replace("\\?", "?").replace("\\'", "'") + "\"\n"
	return result


### Signals


func _on_open_menu_index_pressed(index: int) -> void:
	var item = open_button.get_popup().get_item_text(index)
	match item:
		"Open...":
			open_dialog.popup_centered()
		"Clear recent files":
			DialogueSettings.clear_recent_files()
			build_open_menu()
		_:
			open_file(item)


func _on_insert_button_menu_id_pressed(id: int) -> void:
	match id:
		0:
			code_edit.insert_bbcode("[wave amp=25 freq=5]", "[/wave]")
		1:
			code_edit.insert_bbcode("[shake rate=20 level=10]", "[/shake]")
		3:
			code_edit.insert_bbcode("[wait=1]")
		4:
			code_edit.insert_bbcode("[speed=0.2]")
		5:
			code_edit.insert_bbcode("[next=auto]")


func _on_translations_button_menu_id_pressed(id: int) -> void:
	match id:
		0:
			generate_translations_keys()
		2:
			export_dialog.filters = PackedStringArray(["*.csv ; Translation CSV"])
			export_dialog.current_path = get_last_export_path("csv")
			export_dialog.popup_centered()
		3:
			import_dialog.current_path = get_last_export_path("csv")
			import_dialog.popup_centered()
		5:
			export_dialog.filters = PackedStringArray(["*.po ; Translation"])
			export_dialog.current_path = get_last_export_path("po")
			export_dialog.popup_centered()


func _on_main_view_theme_changed():
	apply_theme()


func _on_main_view_visibility_changed() -> void:
	if visible and is_instance_valid(code_edit):
		code_edit.grab_focus()


func _on_current_file_button_pressed() -> void:
	var file_system = editor_plugin.get_editor_interface().get_file_system_dock()
	file_system.navigate_to_path(current_file_path)


func _on_new_button_pressed() -> void:
	new_dialog.popup_centered()


func _on_new_dialog_file_selected(path: String) -> void:
	open_file(path)


func _on_open_button_about_to_popup() -> void:
	build_open_menu()


func _on_open_dialog_file_selected(path: String) -> void:
	open_file(path)


func _on_code_edit_text_changed() -> void:
	title_list.titles = code_edit.get_titles()
	update_current_file_button()
	parse_timer.start(1)


func _on_code_edit_active_title_change(title: String) -> void:
	title_list.select_title(title)
	DialogueSettings.set_user_value("run_title", title)


func _on_code_edit_caret_changed() -> void:
	DialogueSettings.set_caret(current_file_path, code_edit.get_cursor())


func _on_code_edit_error_clicked(line_number: int) -> void:
	errors_panel.show_error_for_line_number(line_number)


func _on_title_list_title_selected(title: String) -> void:
	code_edit.go_to_title(title)
	code_edit.grab_focus()


func _on_parse_timer_timeout() -> void:
	parse_timer.stop()
	parse()


func _on_errors_panel_error_pressed(line_number: int) -> void:
	code_edit.set_caret_line(line_number)
	code_edit.grab_focus()


func _on_export_dialog_file_selected(path: String) -> void:
	DialogueSettings.set_user_value("last_export_path", path.get_base_dir())
	match path.get_extension():
		"csv":
			export_translations_to_csv(path)
		"po":
			export_translations_to_po(path)


func _on_import_dialog_file_selected(path: String) -> void:
	DialogueSettings.set_user_value("last_export_path", path.get_base_dir())
	import_translations_from_csv(path)


func _on_search_button_toggled(button_pressed: bool) -> void:
	if code_edit.last_selected_text:
		search_and_replace.input.text = code_edit.last_selected_text
		
	search_and_replace.visible = button_pressed


func _on_search_and_replace_open_requested() -> void:
	search_button.set_pressed_no_signal(true)
	search_and_replace.visible = true


func _on_search_and_replace_close_requested() -> void:
	search_button.set_pressed_no_signal(false)
	search_and_replace.visible = false
	code_edit.grab_focus()


func _on_settings_button_pressed() -> void:
	settings_dialog.popup_centered()


func _on_settings_view_script_button_pressed(path: String) -> void:
	settings_dialog.hide()
	editor_plugin.get_editor_interface().edit_resource(load(path))


func _on_test_button_pressed() -> void:
	apply_changes()
	
	if errors_panel.errors.size() > 0:
		errors_dialog.popup_centered()
		return
	
	DialogueSettings.set_user_value("is_running_test_scene", true)
	DialogueSettings.set_user_value("run_resource_path", current_file_path)
	editor_plugin.get_editor_interface().play_custom_scene("res://addons/dialogue_manager/views/test_scene.tscn")


func _on_settings_dialog_confirmed() -> void:
	parse()
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if DialogueSettings.get_setting("wrap_lines", false) else TextEdit.LINE_WRAPPING_NONE
	code_edit.grab_focus()


func _on_docs_button_pressed() -> void:
	OS.shell_open("https://github.com/nathanhoad/godot_dialogue_manager")

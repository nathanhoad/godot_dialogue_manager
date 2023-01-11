@tool
extends Control


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueParser = preload("res://addons/dialogue_manager/components/parser.gd")
const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")

const ITEM_SAVE = 100
const ITEM_SAVE_AS = 101
const ITEM_CLOSE = 102
const ITEM_CLOSE_ALL = 103
const ITEM_CLOSE_OTHERS = 104
const ITEM_COPY_PATH = 200
const ITEM_SHOW_IN_FILESYSTEM = 201


@onready var parse_timer := $ParseTimer

# Dialogs
@onready var new_dialog: FileDialog = $NewDialog
@onready var save_dialog: FileDialog = $SaveDialog
@onready var open_dialog: FileDialog = $OpenDialog
@onready var export_dialog: FileDialog = $ExportDialog
@onready var import_dialog: FileDialog = $ImportDialog
@onready var errors_dialog: AcceptDialog = $ErrorsDialog
@onready var settings_dialog: AcceptDialog = $SettingsDialog
@onready var settings_view := $SettingsDialog/SettingsView
@onready var build_error_dialog: AcceptDialog = $BuildErrorDialog
@onready var close_confirmation_dialog: ConfirmationDialog = $CloseConfirmationDialog
@onready var updated_dialog: AcceptDialog = $UpdatedDialog

# Toolbar
@onready var new_button: Button = %NewButton
@onready var open_button: MenuButton = %OpenButton
@onready var save_all_button: Button = %SaveAllButton
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
@onready var content: HSplitContainer = %Content
@onready var files_list := %FilesList
@onready var files_popup_menu: PopupMenu = %FilesPopupMenu
@onready var title_list := %TitleList
@onready var code_edit := %CodeEdit
@onready var errors_panel := %ErrorsPanel

# The Dialogue Manager plugin
var editor_plugin: EditorPlugin

# The currently open file
var current_file_path: String = "":
	set(next_current_file_path):
		current_file_path = next_current_file_path
		files_list.current_file_path = current_file_path
		if current_file_path == "":
			save_all_button.disabled = true
			test_button.disabled = true
			search_button.disabled = true
			insert_button.disabled = true
			translations_button.disabled = true
			content.dragger_visibility = SplitContainer.DRAGGER_HIDDEN
			files_list.hide()
			title_list.hide()
			code_edit.hide()
		else:
			test_button.disabled = false
			search_button.disabled = false
			insert_button.disabled = false
			translations_button.disabled = false
			content.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
			files_list.show()
			title_list.show()
			code_edit.show()
			
			code_edit.text = open_buffers[current_file_path].text
			code_edit.errors = []
			code_edit.clear_undo_history()
			code_edit.set_cursor(DialogueSettings.get_caret(current_file_path))
			code_edit.grab_focus()
			
			_on_code_edit_text_changed()
			
			errors_panel.errors = []
			code_edit.errors = []
	get:
		return current_file_path

# A reference to the currently open files and their last saved text
var open_buffers: Dictionary = {}


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
			open_buffers = open_buffers
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
	
	save_all_button.disabled = true
	
	close_confirmation_dialog.add_button("Discard", true, "discard")
	
	settings_view.editor_plugin = editor_plugin


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	
	if event is InputEventKey and event.is_pressed():
		match event.as_text():
			"Ctrl+Alt+S":
				save_file(current_file_path)
			"Ctrl+W":
				get_viewport().set_input_as_handled()
				close_file(current_file_path)
			"Ctrl+F5":
				_on_test_button_pressed()


func apply_changes() -> void:
	save_files()


# Load back to the previous buffer regardless of if it was actually saved
func load_from_version_refresh(just_refreshed: Dictionary) -> void:
	if just_refreshed.has("current_file_content"):
		# We just loaded from a version before multiple buffers
		var file: FileAccess = FileAccess.open(just_refreshed.current_file_path, FileAccess.READ)
		var file_text: String = file.get_as_text()
		open_buffers[just_refreshed.current_file_path] = {
			pristine_text = file_text,
			text = just_refreshed.current_file_content
		}
	else:
		open_buffers = just_refreshed.open_buffers
	
	if just_refreshed.current_file_path != "":
		editor_plugin.get_editor_interface().edit_resource(load(just_refreshed.current_file_path))
	else:
		editor_plugin.get_editor_interface().set_main_screen_editor("Dialogue")
	
	updated_dialog.popup_centered()


func new_file(path: String, content: String = "") -> void:
	if open_buffers.has(path):
		remove_file_from_open_buffers(path)
	
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if content == "":
		if DialogueSettings.get_setting("new_with_template", true):
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
	else:
		file.store_string(content)
		
	editor_plugin.get_editor_interface().get_resource_filesystem().scan()


# Open a dialogue resource for editing
func open_resource(resource: Resource) -> void:
	open_file(resource.resource_path)


func open_file(path: String) -> void:
	if not open_buffers.has(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		var text = file.get_as_text()
		
		open_buffers[path] = {
			cursor = Vector2.ZERO,
			text = text,
			pristine_text = text
		}
	
	DialogueSettings.add_recent_file(path)
	build_open_menu()
	
	files_list.files = open_buffers.keys()
	files_list.select_file(path)
	
	self.current_file_path = path


func show_file_in_filesystem(path: String) -> void:
	var file_system = editor_plugin.get_editor_interface().get_file_system_dock()
	file_system.navigate_to_path(path)


# Save any open files
func save_files() -> void:
	for path in open_buffers:
		save_file(path)
		
	# Make sure we reimport/recompile the changes
	editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	save_all_button.disabled = true


# Save a file
func save_file(path: String) -> void:
	var buffer = open_buffers[path]
		
	files_list.mark_file_as_unsaved(path, false)
	save_all_button.disabled = files_list.unsaved_files.size() == 0
	
	# Don't bother saving if there is nothing to save
	if buffer.text == buffer.pristine_text:
		return
		
	buffer.pristine_text = buffer.text
	
	# Save the current text
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(buffer.text)
	file.flush()


func close_file(file: String) -> void:
	if not file in open_buffers.keys(): return
	
	var buffer = open_buffers[file]
	
	if buffer.text == buffer.pristine_text:
		remove_file_from_open_buffers(file)
	else:
		close_confirmation_dialog.dialog_text = "Save changes to '%s'?" % file.get_file()
		close_confirmation_dialog.popup_centered()


func remove_file_from_open_buffers(file: String) -> void:
	if not file in open_buffers.keys(): return
	
	var current_index = open_buffers.keys().find(file)
	
	open_buffers.erase(file)
	if open_buffers.size() == 0:
		self.current_file_path = ""
	else:
		current_index = clamp(current_index, 0, open_buffers.size() - 1)
		self.current_file_path = open_buffers.keys()[current_index]
	files_list.files = open_buffers.keys()


# Apply theme colors and icons to the UI
func apply_theme() -> void:
	if is_instance_valid(editor_plugin) and is_instance_valid(code_edit):
		var editor_settings = editor_plugin.get_editor_interface().get_editor_settings()
		code_edit.colors = {
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
		
		new_button.icon = get_theme_icon("New", "EditorIcons")
		new_button.tooltip_text = "Start a new file"
		
		open_button.icon = get_theme_icon("Load", "EditorIcons")
		open_button.tooltip_text = "Open a file"
		
		save_all_button.icon = get_theme_icon("Save", "EditorIcons")
		save_all_button.tooltip_text = "Save all files"
		
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
		popup.add_separator("Templates")
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "Title", 6)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "Dialogue", 7)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "Response", 8)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "Random Lines", 9)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "Random Text", 10)
		popup.add_separator("Actions")
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "Jump to Title", 11)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), "End Dialogue", 12)
		
		
		
		
		# Set up the translations menu
		popup = translations_button.get_popup()
		popup.clear()
		popup.add_icon_item(get_theme_icon("Translation", "EditorIcons"), "Generate line IDs", 0)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("FileList", "EditorIcons"), "Save to CSV...", 2)
		popup.add_icon_item(get_theme_icon("AssetLib", "EditorIcons"), "Import changes from CSV..." , 3)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("FileList", "EditorIcons"), "Save to PO...", 5)
		
		# Dialog sizes
		var scale: float = editor_plugin.get_editor_interface().get_editor_scale()
		new_dialog.min_size = Vector2(600, 500) * scale
		save_dialog.min_size = Vector2(600, 500) * scale
		open_dialog.min_size = Vector2(600, 500) * scale
		export_dialog.min_size = Vector2(600, 500) * scale
		export_dialog.min_size = Vector2(600, 500) * scale
		settings_dialog.min_size = Vector2(600, 500) * scale


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
	var file: FileAccess
	
	# If the file exists, open it first and work out which keys are already in it
	var existing_csv = {}
	var commas = []
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ)
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
		
	# Start a new file
	file = FileAccess.open(path, FileAccess.WRITE)
	
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
	
	editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	editor_plugin.get_editor_interface().get_file_system_dock().navigate_to_path(path)


# Import changes back from an exported CSV by matching translation keys
func import_translations_from_csv(path: String) -> void:
	var cursor: Vector2 = code_edit.get_cursor()

	if not FileAccess.file_exists(path): return

	# Open the CSV file and build a dictionary of the known keys
	var keys: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var csv_line: Array
	while !file.eof_reached():
		csv_line = file.get_csv_line()
		if csv_line.size() > 1:
			keys[csv_line[0]] = csv_line[1]
	
	var parser: DialogueParser = DialogueParser.new()
	
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
	
	var parser: DialogueParser = DialogueParser.new()
	parser.parse(code_edit.text)
	var dialogue = parser.get_data().lines
	parser.free()

	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)

		if not line.type in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]: continue
		if line.translation_key in id_str: continue

		id_str[line.translation_key] = line.text

	var file: FileAccess

	# If the file exists, keep content except for known entries.
	var existing_po: String = ""
	var already_existing_keys: PackedStringArray = PackedStringArray([])
	if file.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ)
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
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(existing_po)

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


func _on_files_list_file_selected(file_path: String) -> void:
	self.current_file_path = file_path


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
		6:
			code_edit.insert_text("~ title")
		7:
			code_edit.insert_text("Nathan: This is Some Dialogue")
		8:
			code_edit.insert_text("Nathan: Choose a Response...\n- Option 1\n\tNathan: You chose option 1\n- Option 2\n\tNathan: You chose option 2")
		9: 
			code_edit.insert_text("% Nathan: This is random line 1.\n% Nathan: This is random line 2.\n%1 Nathan: This is weighted random line 3.")
		10:
			code_edit.insert_text("Nathan: [[Hi|Hello|Howdy]]")
		11:
			code_edit.insert_text("=> title")
		12:
			code_edit.insert_text("=> END")


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


func _on_new_button_pressed() -> void:
	new_dialog.popup_centered()


func _on_new_dialog_file_selected(path: String) -> void:
	new_file(path)
	open_file(path)


func _on_save_dialog_file_selected(path: String) -> void:
	new_file(path, code_edit.text)
	open_file(path)


func _on_open_button_about_to_popup() -> void:
	build_open_menu()


func _on_open_dialog_file_selected(path: String) -> void:
	open_file(path)
	

func _on_save_all_button_pressed() -> void:
	save_files()


func _on_code_edit_text_changed() -> void:
	title_list.titles = code_edit.get_titles()
	
	var buffer = open_buffers[current_file_path]
	buffer.text = code_edit.text
	files_list.mark_file_as_unsaved(current_file_path, buffer.text != buffer.pristine_text)
	save_all_button.disabled = open_buffers.values().filter(func(d): return d.text != d.pristine_text).size() == 0
	
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
	var test_scene_path: String = DialogueSettings.get_setting("custom_test_scene_path", "res://addons/dialogue_manager/test_scene.tscn")
	editor_plugin.get_editor_interface().play_custom_scene(test_scene_path)


func _on_settings_dialog_confirmed() -> void:
	parse()
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if DialogueSettings.get_setting("wrap_lines", false) else TextEdit.LINE_WRAPPING_NONE
	code_edit.grab_focus()


func _on_docs_button_pressed() -> void:
	OS.shell_open("https://github.com/nathanhoad/godot_dialogue_manager")


func _on_files_list_file_popup_menu_requested(at_position: Vector2) -> void:
	files_popup_menu.position = Vector2(get_viewport().position) + files_list.global_position + at_position
	files_popup_menu.popup()


func _on_files_popup_menu_about_to_popup() -> void:
	files_popup_menu.clear()
	
	files_popup_menu.add_item("Save", ITEM_SAVE, KEY_MASK_CTRL | KEY_MASK_ALT | KEY_S)
	files_popup_menu.add_item("Save As...", ITEM_SAVE_AS)
	files_popup_menu.add_item("Close", ITEM_CLOSE, KEY_MASK_CTRL | KEY_W)
	files_popup_menu.add_item("Close All", ITEM_CLOSE_ALL)
	files_popup_menu.add_item("Close Other Files", ITEM_CLOSE_OTHERS)
	files_popup_menu.add_separator()
	files_popup_menu.add_item("Copy File Path", ITEM_COPY_PATH)
	files_popup_menu.add_item("Show in FileSystem", ITEM_SHOW_IN_FILESYSTEM)


func _on_files_popup_menu_id_pressed(id: int) -> void:
	match id:
		ITEM_SAVE:
			save_file(current_file_path)
		ITEM_SAVE_AS:
			save_dialog.popup_centered()
		ITEM_CLOSE:
			close_file(current_file_path)
		ITEM_CLOSE_ALL:
			for path in open_buffers.keys():
				close_file(path)
		ITEM_CLOSE_OTHERS:
			for path in open_buffers.keys():
				if path != current_file_path:
					close_file(path)
		
		ITEM_COPY_PATH:
			DisplayServer.clipboard_set(current_file_path)
		ITEM_SHOW_IN_FILESYSTEM:
			show_file_in_filesystem(current_file_path)


func _on_code_edit_external_file_requested(path: String, title: String) -> void:
	open_file(path)
	if title != "":
		code_edit.go_to_title(title)
	else:
		code_edit.set_caret_line(0)


func _on_close_confirmation_dialog_confirmed() -> void:
	save_file(current_file_path)
	remove_file_from_open_buffers(current_file_path)


func _on_close_confirmation_dialog_custom_action(action: StringName) -> void:
	if action == "discard":
		remove_file_from_open_buffers(current_file_path)
	close_confirmation_dialog.hide()

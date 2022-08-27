tool
extends Control


const DialogueResource = preload("res://addons/dialogue_manager/dialogue_resource.gd")
const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


onready var settings := $Settings
onready var parser := $Parser
onready var parse_timeout := $ParseTimeout
onready var update_checker := $UpdateChecker
onready var file_label := $Margin/VBox/Toolbar/FileLabel
onready var open_button := $Margin/VBox/Toolbar/OpenButton
onready var content := $Margin/VBox/Content
onready var title_list := $Margin/VBox/Content/VBox/TitleList
onready var error_list := $Margin/VBox/Content/VBox/ErrorList
onready var search_toolbar := $Margin/VBox/Content/VBox2/SearchToolbar
onready var editor := $Margin/VBox/Content/VBox2/CodeEditor
onready var new_dialogue_dialog := $NewDialogueDialog
onready var open_dialogue_dialog := $OpenDialogueDialog
onready var invalid_dialogue_dialog := $InvalidDialogueDialog
onready var settings_dialog := $SettingsDialog
onready var errors_confirm_dialog := $ErrorsConfirmDialog
onready var insert_menu := $Margin/VBox/Toolbar/InsertMenu
onready var translations_menu := $Margin/VBox/Toolbar/TranslationsMenu
onready var save_translations_dialog := $SaveTranslationsDialog
onready var save_translations_dialog_po := $SaveTranslationsDialogPO
onready var import_translations_dialog := $ImportTranslationsDialog
onready var update_button := $Margin/VBox/Toolbar/UpdateButton
onready var error_button := $Margin/VBox/Toolbar/ErrorButton
onready var run_node_button := $Margin/VBox/Toolbar/RunButton
onready var search_button := $Margin/VBox/Toolbar/SearchButton


var plugin
var current_resource: DialogueResource
var has_changed: bool = false
var recent_resources: Array
var pristine_raw_text: String = ""


func _ready() -> void:
	# Hide the editor until we open something
	set_resource(null)
	
	# Check for updates
	update_checker.check_for_updates()
	update_button.visible = false
	update_button.add_color_override("font_color", get_color("success_color", "Editor"))
	
	# Set up the button icons
	$Margin/VBox/Toolbar/NewButton.text = ""
	$Margin/VBox/Toolbar/NewButton.icon = get_icon("New", "EditorIcons")
	open_button.text = ""
	open_button.icon = get_icon("Load", "EditorIcons")
	$Margin/VBox/Toolbar/SettingsButton.text = ""
	$Margin/VBox/Toolbar/SettingsButton.icon = get_icon("Tools", "EditorIcons")
	error_button.text = ""
	error_button.icon = get_icon("Debug", "EditorIcons")
	run_node_button.text = ""
	run_node_button.icon = get_icon("PlayScene", "EditorIcons")
	search_button.icon = get_icon("Search", "EditorIcons")
	$Margin/VBox/Toolbar/TranslationsMenu.icon = get_icon("Translation", "EditorIcons")
	$Margin/VBox/Toolbar/HelpButton.icon = get_icon("Help", "EditorIcons")
	
	insert_menu.icon = get_icon("RichTextEffect", "EditorIcons")
	var popup = insert_menu.get_popup()
	popup.set_item_icon(0, get_icon("RichTextEffect", "EditorIcons"))
	popup.set_item_icon(1, get_icon("RichTextEffect", "EditorIcons"))
	popup.set_item_icon(3, get_icon("Time", "EditorIcons"))
	popup.set_item_icon(4, get_icon("ViewportSpeed", "EditorIcons"))
	popup.set_item_icon(5, get_icon("DebugNext", "EditorIcons"))
	insert_menu.get_popup().connect("id_pressed", self, "_on_insert_menu_id_pressed")
	
	popup = translations_menu.get_popup()
	popup.set_item_icon(0, get_icon("Translation", "EditorIcons"))
	popup.set_item_icon(1, get_icon("FileList", "EditorIcons"))
	popup.set_item_icon(2, get_icon("FileList", "EditorIcons"))
	popup.set_item_icon(4, get_icon("AssetLib", "EditorIcons"))
	translations_menu.get_popup().connect("id_pressed", self, "_on_translation_menu_id_pressed")
	
	search_toolbar.visible = false
	
	# Get version number
	var config = ConfigFile.new()
	var err = config.load("res://addons/dialogue_manager/plugin.cfg")
	if err == OK:
		$Margin/VBox/Toolbar/VersionLabel.text = "v" + config.get_value("plugin", "version")
	
	file_label.icon = get_icon("Filesystem", "EditorIcons")
	
	recent_resources = settings.get_user_value("recent_resources", [])
	build_open_menu()
	
	editor.wrap_enabled = settings.get_editor_value("wrap_lines", false)


func apply_changes() -> void:
	if is_instance_valid(editor) and current_resource != null:
		current_resource.set("raw_text", editor.text)
		
		if pristine_raw_text != current_resource.raw_text:
			current_resource.set("resource_version", current_resource.resource_version + 1)
			pristine_raw_text = current_resource.raw_text
		
		ResourceSaver.save(current_resource.resource_path, current_resource)
		parse(true)


### Helpers


func build_open_menu() -> void:
	var menu = open_button.get_popup()
	menu.clear()
	menu.add_icon_item(get_icon("Load", "EditorIcons"), "Open...")
	menu.add_separator()
	
	if recent_resources.size() == 0:
		menu.add_item("No recent files")
		menu.set_item_disabled(2, true)
	else:
		for path in recent_resources:
			menu.add_icon_item(get_icon("File", "EditorIcons"), path)
			
	menu.add_separator()
	menu.add_item("Clear recent files")
	if menu.is_connected("index_pressed", self, "_on_open_menu_index_pressed"):
		menu.disconnect("index_pressed", self, "_on_open_menu_index_pressed")
	menu.connect("index_pressed", self, "_on_open_menu_index_pressed")


func set_resource(value: DialogueResource) -> void:
	apply_changes()
	
	current_resource = value
	if current_resource:
		file_label.text = get_nice_file(current_resource.resource_path)
		file_label.visible = true
		editor.text = current_resource.raw_text
		editor.clear_undo_history()
		var cursors = settings.get_user_value("resource_cursors", {})
		if cursors.has(current_resource.resource_path):
			var cursor = cursors.get(current_resource.resource_path)
			editor.cursor_set_line(cursor.y, true)
			editor.cursor_set_column(cursor.x, true)
		content.visible = true
		error_button.disabled = false
		run_node_button.disabled = false
		search_button.disabled = false
		insert_menu.disabled = false
		translations_menu.disabled = false
		_on_CodeEditor_text_changed()
		has_changed = false
		pristine_raw_text = current_resource.raw_text
		
	else:
		content.visible = false
		file_label.visible = false
		error_button.disabled = true
		run_node_button.disabled = true
		search_button.disabled = true
		insert_menu.disabled = true
		translations_menu.disabled = true


func get_nice_file(file: String) -> String:
	var bits = file.replace("res://", "").split("/")
	if bits.size() == 1:
		return bits[0]
	else:
		return "%s/%s" % [bits[bits.size() - 2], bits[bits.size() - 1]]


func get_last_csv_path() -> String:
	var filename = current_resource.resource_path.get_file().replace(".tres", ".csv")
	return settings.get_user_value("last_csv_path", current_resource.resource_path.get_base_dir()) + "/" + filename


func open_resource(resource: DialogueResource) -> void:
	apply_upgrades(resource)
	set_resource(resource)
	# Add this to our list of recent resources
	if resource.resource_path in recent_resources:
		recent_resources.erase(resource.resource_path)
	recent_resources.insert(0, resource.resource_path)
	settings.set_user_value("recent_resources", recent_resources)
	build_open_menu()
	parse(true)


func open_resource_from_path(path: String) -> void:
	var resource = load(path)
	if resource is DialogueResource:
		open_resource(resource)
	else:
		invalid_dialogue_dialog.popup_centered()


func apply_upgrades(resource: DialogueResource) -> void:
	if resource == null: return
	if not resource is DialogueResource: return
	
	var lines = resource.raw_text.split("\n")
	for i in range(0, lines.size()):
		var line: String = lines[i]
		if resource.syntax_version == 0:
			if line.begins_with("# "):
				line = "~ " + line.substr(2).replace(" ", "_")
			line = line.replace("// ", "# ")
			if "goto #" in line:
				var index = line.find("goto # ")
				line = line.substr(0, index) + "=> " + line.substr(index + 7).replace(" ", "_")
		lines[i] = line
	
	resource.set("syntax_version", DialogueConstants.SYNTAX_VERSION)
	resource.set("raw_text", lines.join("\n"))
	

func parse(force_show_errors: bool = false) -> void:
	if current_resource == null: return
	if not has_changed and not force_show_errors: return
	
	var result = parser.parse(editor.text)
	
	if settings.get_editor_value("store_compiler_results", true):
		current_resource.set("titles", result.titles)
		current_resource.set("lines", result.lines)
		current_resource.set("errors", result.errors)
	else:
		current_resource.set("titles", {})
		current_resource.set("lines", {})
		current_resource.set("errors", [])
	ResourceSaver.save(current_resource.resource_path, current_resource)
	
	has_changed = false
	
	if force_show_errors or settings.get_editor_value("check_for_errors") or error_list.errors.size() > 0:
		error_list.errors = result.errors
		
		for line_number in range(0, editor.get_line_count()):
			editor.set_line_as_bookmark(line_number, false)
			for error in result.errors:
				if error.get("line") == line_number:
					editor.set_line_as_bookmark(line_number, true)


func generate_translations_keys() -> void:
	randomize()
	seed(OS.get_unix_time())
	
	var cursor: Vector2 = editor.get_cursor()
	
	var lines: PoolStringArray = editor.text.split("\n")
	
	var key_regex = RegEx.new()
	key_regex.compile("\\[TR:(?<key>.*?)\\]")
	
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
		
		if "[TR:" in line: continue
		
		var key = "t" + str(randi() % 1000000).sha1_text().substr(0, 10)
		while key in known_keys:
			key = "t" + str(randi() % 1000000).sha1_text().substr(0, 10)
		
		var text = ""
		if l.begins_with("- "):
			text = parser.extract_response_prompt(l)
		else:
			text = l.substr(l.find(":") + 1)
		
		lines[i] = line.replace(text, text + " [TR:%s]" % key)
		known_keys[key] = text
	
	editor.text = lines.join("\n")
	editor.set_cursor(cursor)
	_on_CodeEditor_text_changed()


func save_translations(path: String) -> void:
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
			if line.size() > 0 and line[0].strip_edges() != "":
				existing_csv[line[0]] = line
		file.close()
		
	# Start a new file
	file.open(path, File.WRITE)
	
	if not file.file_exists(path):
		file.store_csv_line(["keys", "en"])

	# Write our translations to file	
	var known_keys: PoolStringArray = []
	var dialogue = parser.parse(editor.text).get("lines")
	
	# Make a list of stuff that needs to go into the file
	var lines_to_save = []
	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)
		
		if not line.get("type") in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]: continue
		if line.get("translation_key") in known_keys: continue
		
		known_keys.append(line.get("translation_key"))
		
		if existing_csv.has(line.get("translation_key")):
			var existing_line = existing_csv.get(line.get("translation_key"))
			existing_line[1] = line.get("text")
			lines_to_save.append(existing_line)
			existing_csv.erase(line.get("translation_key"))
		else:
			lines_to_save.append(PoolStringArray([line.get("translation_key"), line.get("text")] + commas))
	
	# Store lines in the file, starting with anything that already exists that hasn't been touched
	for line in existing_csv.values():
		file.store_csv_line(line)
	for line in lines_to_save:
		file.store_csv_line(line)
	
	file.close()
	
	plugin.get_editor_interface().get_resource_filesystem().scan()
	plugin.get_editor_interface().get_file_system_dock().navigate_to_path(path)


func save_translations_po(path: String) -> void:
	var id_str: Dictionary = {}
	var dialogue = parser.parse(editor.text).get("lines")

	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)

		if not line.get("type") in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]: continue
		if line.get("translation_key") in id_str: continue

		id_str[line.get("translation_key")] = line.get("text")

	var file = File.new()

	# If the file exists, keep content except for known entries.
	var existing_po: String = ""
	var already_existing_keys: PoolStringArray = PoolStringArray()
	if file.file_exists(path):
		file.open(path, File.READ)
		var line: String
		while !file.eof_reached():
			line = file.get_line().strip_edges()

			if line.begins_with("msgid"): # Extract msgid
				var msgid = line.trim_prefix("msgid \"").trim_suffix("\"").c_unescape()
				existing_po += line + "\n"
				line = file.get_line().strip_edges()
				while !line.begins_with("msgstr") and !file.eof_reached():
					if line.begins_with("\""):
						msgid += line.trim_prefix("\"").trim_suffix("\"").c_unescape()
					existing_po += line + "\n"
					line = file.get_line().strip_edges()

				already_existing_keys.append(msgid)
				if msgid in id_str:
					existing_po += generate_po_line("msgstr", id_str[msgid])
					# skip old msgstr
					while !file.eof_reached() and !line.empty() and (line.begins_with("msgstr") or line.begins_with("\"")):
						line = file.get_line().strip_edges()
					existing_po += line + "\n"
				else: # keep unknown msgstr
					existing_po += line + "\n"
					while !file.eof_reached() and !line.empty() and (line.begins_with("msgstr") or line.begins_with("\"")):
						line = file.get_line().strip_edges()
						existing_po += line + "\n"
			else: # keep old lines
				existing_po += line + "\n"
		file.close()

	# Godot requires the config in the PO regardless of whether it constains anything relevant.
	if !("" in already_existing_keys):
		existing_po += generate_po_line("msgid", "")
		existing_po += "msgstr \"\"\n\"Content-Type: text/plain; charset=UTF-8\\n\"" + "\n" + "\n"

	for key in id_str:
		if !(key in already_existing_keys):
			existing_po += generate_po_line("msgid", key)
			existing_po += generate_po_line("msgstr", id_str[key]) + "\n"

	existing_po = existing_po.trim_suffix("\n")

	# Start a new file
	file.open(path, File.WRITE)
	file.store_string(existing_po)
	file.close()

	plugin.get_editor_interface().get_resource_filesystem().scan()
	plugin.get_editor_interface().get_file_system_dock().navigate_to_path(path)


# type is supposed to be either msgid or msgstr
func generate_po_line(type: String, line) -> String:
	var result: String
	if "\n" in line: # multiline
		result += type + " \"\"\n"
		var lines: PoolStringArray = line.split("\n")
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


func _on_open_menu_index_pressed(index):
	var item = open_button.get_popup().get_item_text(index)
	match item:
		"Open...":
			open_dialogue_dialog.popup_centered()
		"Clear recent files":
			recent_resources.clear()
			settings.set_user_value("recent_resources", recent_resources)
			settings.set_user_value("resource_cursors", {})
			build_open_menu()
		_:
			open_resource_from_path(item)


func _on_insert_menu_id_pressed(id):
	match id:
		0:
			editor.insert_bbcode("[wave amp=25 freq=5]", "[/wave]")
		1:
			editor.insert_bbcode("[shake rate=20 level=10]", "[/shake]")
		3:
			editor.insert_bbcode("[wait=1]")
		4:
			editor.insert_bbcode("[speed=0.2]")
		5:
			editor.insert_bbcode("[next=auto]")


func _on_translation_menu_id_pressed(id):
	match id:
		0:
			generate_translations_keys()
		1:
			save_translations_dialog.current_path = get_last_csv_path()
			save_translations_dialog.popup_centered()
		2:
			save_translations_dialog_po.current_path = get_last_csv_path().replace(".csv", ".po")
			save_translations_dialog_po.popup_centered()
		4:
			import_translations_dialog.current_path = get_last_csv_path()
			import_translations_dialog.popup_centered()


func _on_CodeEditor_text_changed():
	has_changed = true
	title_list.titles = editor.get_titles()
	parse_timeout.start(1)


func _on_NewButton_pressed():
	new_dialogue_dialog.popup_centered()


func _on_NewDialogueDialog_file_selected(path):
	var resource = DialogueResource.new()
	resource.take_over_path(path)
	ResourceSaver.save(path, resource)
	open_resource(resource)


func _on_FileLabel_pressed():
	var file_system = plugin.get_editor_interface().get_file_system_dock()
	file_system.navigate_to_path(current_resource.resource_path)


func _on_SettingsButton_pressed():
	settings_dialog.popup_centered()


func _on_CodeEditor_active_title_changed(title):
	title_list.select_title(title)
	settings.set_user_value("run_title", title)
	run_node_button.hint_tooltip = "Play the test scene using \"%s\"" % title


func _on_CodeEditor_cursor_changed():
	var next_resource_cursors = settings.get_user_value("resource_cursors", {})
	next_resource_cursors[current_resource.resource_path] = { 
		x = editor.cursor_get_column(), 
		y = editor.cursor_get_line() 
	}
	settings.set_user_value("resource_cursors", next_resource_cursors)


func _on_ParseTimeout_timeout():
	parse_timeout.stop()
	parse()
	

func _on_TitleList_title_clicked(title):
	editor.go_to_title(title)


func _on_OpenDialogueDialog_file_selected(path):
	open_resource_from_path(path)


func _on_OpenDialogueDialog_confirmed():
	open_resource_from_path(open_dialogue_dialog.current_path)


func _on_SettingsDialog_popup_hide():
	parse(true)
	editor.wrap_enabled = settings.get_editor_value("wrap_lines", false)
	editor.grab_focus()


func _on_ErrorList_error_pressed(error):
	editor.cursor_set_line(error.get("line"))


func _on_HelpButton_pressed():
	OS.shell_open("https://github.com/nathanhoad/godot_dialogue_manager/tree/v1.x")


func _on_SaveTranslationsDialog_file_selected(path):
	settings.set_user_value("last_csv_path", path.get_base_dir())
	save_translations(path)


func _on_SaveTranslationsDialogPO_file_selected(path):
	settings.set_user_value("last_csv_path", path.get_base_dir())
	save_translations_po(path)


func _on_UpdateChecker_has_update(version, url):
	update_button.visible = true
	update_button.text = "v" + version + " available!"


func _on_UpdateButton_pressed():
	OS.shell_open(update_checker.plugin_url)


func _on_ErrorButton_pressed():
	parse(true)


func _on_SettingsDialog_script_button_pressed(path):
	plugin.get_editor_interface().edit_resource(load(path))


func _on_RunButton_pressed():
	if current_resource.errors.size() > 0:
		errors_confirm_dialog.popup_centered()
		return
		
	settings.set_user_value("run_resource_path", current_resource.resource_path)
	plugin.get_editor_interface().play_custom_scene("res://addons/dialogue_manager/views/test_scene.tscn")


func _on_SearchButton_toggled(button_pressed):
	if editor.last_selection_text:
		search_toolbar.input.text = editor.last_selection_text
		
	search_toolbar.visible = button_pressed


func _on_SearchToolbar_close_requested():
	search_button.pressed = false
	search_toolbar.visible = false
	editor.grab_focus()


func _on_SearchToolbar_open_requested():
	search_button.pressed = true
	search_toolbar.visible = true


func _on_ImportTranslationsDialog_file_selected(path):
	settings.set_user_value("last_csv_path", path.get_base_dir())
	
	var cursor: Vector2 = editor.get_cursor()

	# Open the CSV file and build a dictionary of the known keys
	var file = File.new()
	
	if not file.file_exists(path): return

	var keys = {}
	file.open(path, File.READ)
	var csv_line: Array
	while !file.eof_reached():
		csv_line = file.get_csv_line()
		if csv_line.size() > 1:
			keys[csv_line[0]] = csv_line[1]
	file.close()
	
	# Now look over each line in the dialogue and replace the content for matched keys
	var lines = editor.text.split("\n")
	var start_index: int = 0
	var end_index: int = 0
	for i in range(0, lines.size()):
		var line = lines[i]
		var translation_key = parser.extract_translation(line)
		if keys.has(translation_key):
			if parser.is_dialogue_line(line):
				start_index = 0
				# See if we need to skip over a character name
				line = line.replace("\\:", "!ESCAPED_COLON!")
				if ": " in line:
					start_index = line.find(": ") + 2
				lines[i] = (line.substr(0, start_index) + keys.get(translation_key) + " [TR:" + translation_key + "]").replace("!ESCAPED_COLON!", ":")
				
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
				lines[i] = (line.substr(0, start_index) + keys.get(translation_key) + " [TR:" + translation_key + "]" + line.substr(end_index)).replace("!ESCAPED_COLON!", ":")
	
	editor.text = lines.join("\n")
	editor.set_cursor(cursor)

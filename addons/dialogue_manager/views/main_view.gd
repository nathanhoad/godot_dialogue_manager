tool
extends Control


const DialogueResource = preload("res://addons/dialogue_manager/dialogue_resource.gd")
const Constants = preload("res://addons/dialogue_manager/constants.gd")


onready var settings := $Settings
onready var parser := $Parser
onready var parse_timeout := $ParseTimeout
onready var update_checker := $UpdateChecker
onready var file_label := $Margin/VBox/Toolbar/FileLabel
onready var open_button := $Margin/VBox/Toolbar/OpenButton
onready var content := $Margin/VBox/Content
onready var title_list := $Margin/VBox/Content/VBox/TitleList
onready var error_list := $Margin/VBox/Content/VBox/ErrorList
onready var editor := $Margin/VBox/Content/CodeEditor
onready var new_dialogue_dialog := $NewDialogueDialog
onready var open_dialogue_dialog := $OpenDialogueDialog
onready var invalid_dialogue_dialog := $InvalidDialogueDialog
onready var settings_dialog := $SettingsDialog
onready var translations_menu := $Margin/VBox/Toolbar/TranslationsMenu
onready var save_translations_dialog := $SaveTranslationsDialog
onready var update_button := $Margin/VBox/Toolbar/UpdateButton
onready var error_button := $Margin/VBox/Toolbar/ErrorButton
onready var run_node_button := $Margin/VBox/Toolbar/RunButton


var plugin
var current_resource: DialogueResource
var has_changed: bool = false
var recent_resources: Array


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
	$Margin/VBox/Toolbar/ErrorButton.text = ""
	$Margin/VBox/Toolbar/ErrorButton.icon = get_icon("Debug", "EditorIcons")
	$Margin/VBox/Toolbar/RunButton.text = ""
	$Margin/VBox/Toolbar/RunButton.icon = get_icon("PlayScene", "EditorIcons")
	$Margin/VBox/Toolbar/TranslationsMenu.icon = get_icon("Translation", "EditorIcons")
	$Margin/VBox/Toolbar/HelpButton.icon = get_icon("Help", "EditorIcons")
	var popup = translations_menu.get_popup()
	popup.set_item_icon(0, get_icon("Translation", "EditorIcons"))
	popup.set_item_icon(1, get_icon("FileList", "EditorIcons"))
	
	# Get version number
	var config = ConfigFile.new()
	var err = config.load("res://addons/dialogue_manager/plugin.cfg")
	if err == OK:
		$Margin/VBox/Toolbar/VersionLabel.text = "v" + config.get_value("plugin", "version")
	
	file_label.icon = get_icon("Filesystem", "EditorIcons")
	
	translations_menu.get_popup().connect("id_pressed", self, "_on_translation_menu_id_pressed")
	
	if settings.has_editor_value("recent_resources"):
		recent_resources = settings.get_editor_value("recent_resources")
	build_open_menu()


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
	current_resource = value
	if current_resource:
		file_label.text = get_nice_file(current_resource.resource_path)
		file_label.visible = true
		editor.text = current_resource.raw_text
		content.visible = true
		error_button.disabled = false
		run_node_button.disabled = false
		translations_menu.disabled = false
		_on_CodeEditor_text_changed()
		has_changed = false
	else:
		content.visible = false
		file_label.visible = false
		error_button.disabled = true
		run_node_button.disabled = true
		translations_menu.disabled = true


func get_nice_file(file: String) -> String:
	var bits = file.replace("res://", "").split("/")
	if bits.size() == 1:
		return bits[0]
	else:
		return "%s/%s" % [bits[bits.size() - 2], bits[bits.size() - 1]]


func open_resource(resource: DialogueResource) -> void:
	parse(true)
	apply_upgrades(resource)
	set_resource(resource)
	# Add this to our list of recent resources
	if resource.resource_path in recent_resources:
		recent_resources.erase(resource.resource_path)
	recent_resources.insert(0, resource.resource_path)
	settings.set_editor_value("recent_resources", recent_resources)
	build_open_menu()
	parse(true)



func open_resource_from_path(path: String) -> void:
	var resource = load(path)
	if resource is DialogueResource:
		open_resource(resource)
	else:
		invalid_dialogue_dialog.popup_centered()


func apply_upgrades(resource: DialogueResource) -> void:
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
	
	resource.raw_text = lines.join("\n")
	

func parse(force_show_errors: bool = false) -> void:
	if not current_resource: return
	if not has_changed and not force_show_errors: return
	
	var result = parser.parse(editor.text)
	
	current_resource.syntax_version = Constants.SYNTAX_VERSION
	current_resource.titles = result.get("titles")
	current_resource.lines = result.get("lines")
	current_resource.errors = result.get("errors")
	ResourceSaver.save(current_resource.resource_path, current_resource)
	
	has_changed = false
	
	if force_show_errors or settings.get_editor_value("check_for_errors") or error_list.errors.size() > 0:
		error_list.errors = current_resource.errors
		
		for line_number in range(0, editor.get_line_count() - 1):
			editor.set_line_as_bookmark(line_number, false)
			for error in current_resource.errors:
				if error.get("line") == line_number:
					editor.set_line_as_bookmark(line_number, true)


func generate_translations_keys() -> void:
	randomize()
	seed(OS.get_unix_time())
	
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
				text = parser.extract_response(l)
			elif ":" in l:
				text = l.split(":")[1]
			else:
				text = l
			known_keys[found.strings[found.names.get("key")]] = text
	
	# Add in any that are missing
	for i in lines.size():
		var line = lines[i]
		var l = line.strip_edges()
		
		if l == "" or l.begins_with("# "): continue
		if l.begins_with("if ") or l.begins_with("elif ") or l.begins_with("else") or l.begins_with("endif"): continue
		if l.begins_with("~ "): continue
		if l.begins_with("do ") or l.begins_with("set "): continue
		if l.begins_with("=>"): continue
		
		if "[TR:" in line: continue
		
		var key = "t" + str(randi() % 1000000).sha1_text().substr(0, 10)
		while key in known_keys:
			key = "t" + str(randi() % 1000000).sha1_text().substr(0, 10)
		
		# See if identical text already has a key
		var text = ""
		if l.begins_with("- "):
			text = parser.extract_response(l)
		else:
			text = l.substr(l.find(":") + 1)
			
		var index = known_keys.values().find(text)
		if index > -1:
			key = known_keys.keys()[index]
		lines[i] = line.replace(text, text + " [TR:%s]" % key)
		known_keys[key] = text
	
	editor.text = lines.join("\n")
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
		
		if not line.get("type") in [Constants.TYPE_DIALOGUE, Constants.TYPE_RESPONSE]: continue
		if line.get("text") in known_keys: continue
		
		known_keys.append(line.get("text"))
		if existing_csv.has(line.get("translation_key")):
			var existing_line = existing_csv.get(line.get("translation_key"))
			existing_line[1] = line.get("text")
			lines_to_save.append(existing_line)
			existing_csv.erase(line.get("translation_key"))
		else:
			known_keys.append(line.get("text"))
			lines_to_save.append(PoolStringArray([line.get("translation_key"), line.get("text")] + commas))
	
	# Store lines in the file, starting with anything that already exists that hasn't been touched
	for line in existing_csv.values():
		file.store_csv_line(line)
	for line in lines_to_save:
		file.store_csv_line(line)
	
	file.close()
	
	plugin.get_editor_interface().get_resource_filesystem().scan()
	plugin.get_editor_interface().get_file_system_dock().navigate_to_path(path)


### Signals


func _on_open_menu_index_pressed(index):
	var item = open_button.get_popup().get_item_text(index)
	match item:
		"Open...":
			open_dialogue_dialog.popup_centered()
		"Clear recent files":
			recent_resources.clear()
			settings.set_editor_value("recent_resources", recent_resources)
			build_open_menu()
		_:
			open_resource_from_path(item)


func _on_translation_menu_id_pressed(id):
	match id:
		0:
			generate_translations_keys()
		1:
			save_translations_dialog.current_path = current_resource.resource_path.replace(".tres", ".csv")
			save_translations_dialog.popup_centered()


func _on_CodeEditor_text_changed():
	has_changed = true
	current_resource.raw_text = editor.text
	ResourceSaver.save(current_resource.resource_path, current_resource)
	title_list.titles = editor.get_titles()
	parse_timeout.start(1)


func _on_NewButton_pressed():
	new_dialogue_dialog.popup_centered()


func _on_NewDialogueDialog_file_selected(path):
	var resource = DialogueResource.new()
	resource.take_over_path(path)
	resource.raw_text = "~ this_is_a_node_title\n\nNathan: This is some dialogue.\nNathan: Here are some choices.\n- First one\n\tNathan: You picked the first one.\n- Second one\n\tNathan: You picked the second one.\n- Start again => this_is_a_node_title\n- End the conversation => END\nNathan: For more information about conditional dialogue, mutations, and all the fun stuff, see the online documentation."
	resource.syntax_version = Constants.SYNTAX_VERSION
	ResourceSaver.save(path, resource)
	open_resource(resource)


func _on_FileLabel_pressed():
	var file_system = plugin.get_editor_interface().get_file_system_dock()
	file_system.navigate_to_path(current_resource.resource_path)


func _on_SettingsButton_pressed():
	settings_dialog.popup_centered()


func _on_CodeEditor_active_title_changed(title):
	title_list.select_title(title)
	settings.set_editor_value("run_title", title)
	run_node_button.hint_tooltip = "Play the test scene using \"%s\"" % title


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
	parse()


func _on_ErrorList_error_pressed(error):
	editor.cursor_set_line(error.get("line"))


func _on_HelpButton_pressed():
	OS.shell_open("https://github.com/nathanhoad/godot_dialogue_manager")


func _on_SaveTranslationsDialog_file_selected(path):
	save_translations(path)


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
	if settings.has_editor_value("run_title"):
		settings.set_editor_value("run_resource", current_resource.resource_path)
		plugin.get_editor_interface().play_custom_scene("res://addons/dialogue_manager/views/test_scene.tscn")

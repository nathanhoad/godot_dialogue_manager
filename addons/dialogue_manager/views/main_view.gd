@tool
extends Control


const DialogueConstants = preload("../constants.gd")
const DialogueSettings = preload("../settings.gd")
const DialogueResource = preload("../dialogue_resource.gd")
const DialogueManagerParser = preload("../components/parser.gd")

const OPEN_OPEN = 100
const OPEN_QUICK = 101
const OPEN_CLEAR = 102

const TRANSLATIONS_GENERATE_LINE_IDS = 100
const TRANSLATIONS_SAVE_CHARACTERS_TO_CSV = 201
const TRANSLATIONS_SAVE_TO_CSV = 202
const TRANSLATIONS_IMPORT_FROM_CSV = 203

const ITEM_SAVE = 100
const ITEM_SAVE_AS = 101
const ITEM_CLOSE = 102
const ITEM_CLOSE_ALL = 103
const ITEM_CLOSE_OTHERS = 104
const ITEM_COPY_PATH = 200
const ITEM_SHOW_IN_FILESYSTEM = 201

enum TranslationSource {
	CharacterNames,
	Lines
}


signal confirmation_closed()


@onready var parse_timer := $ParseTimer

# Dialogs
@onready var new_dialog: FileDialog = $NewDialog
@onready var save_dialog: FileDialog = $SaveDialog
@onready var open_dialog: FileDialog = $OpenDialog
@onready var quick_open_dialog: ConfirmationDialog = $QuickOpenDialog
@onready var quick_open_files_list: VBoxContainer = $QuickOpenDialog/QuickOpenFilesList
@onready var export_dialog: FileDialog = $ExportDialog
@onready var import_dialog: FileDialog = $ImportDialog
@onready var errors_dialog: AcceptDialog = $ErrorsDialog
@onready var settings_dialog: AcceptDialog = $SettingsDialog
@onready var settings_view := $SettingsDialog/SettingsView
@onready var build_error_dialog: AcceptDialog = $BuildErrorDialog
@onready var close_confirmation_dialog: ConfirmationDialog = $CloseConfirmationDialog
@onready var updated_dialog: AcceptDialog = $UpdatedDialog
@onready var find_in_files_dialog: AcceptDialog = $FindInFilesDialog
@onready var find_in_files: Control = $FindInFilesDialog/FindInFiles

# Toolbar
@onready var new_button: Button = %NewButton
@onready var open_button: MenuButton = %OpenButton
@onready var save_all_button: Button = %SaveAllButton
@onready var find_in_files_button: Button = %FindInFilesButton
@onready var test_button: Button = %TestButton
@onready var search_button: Button = %SearchButton
@onready var insert_button: MenuButton = %InsertButton
@onready var translations_button: MenuButton = %TranslationsButton
@onready var settings_button: Button = %SettingsButton
@onready var support_button: Button = %SupportButton
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

# The currently open file
var current_file_path: String = "":
	set(next_current_file_path):
		current_file_path = next_current_file_path
		files_list.current_file_path = current_file_path
		if current_file_path == "" or not open_buffers.has(current_file_path):
			save_all_button.disabled = true
			test_button.disabled = true
			search_button.disabled = true
			insert_button.disabled = true
			translations_button.disabled = true
			content.dragger_visibility = SplitContainer.DRAGGER_HIDDEN
			files_list.hide()
			title_list.hide()
			code_edit.hide()
			errors_panel.hide()
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

# Which thing are we exporting translations for?
var translation_source: TranslationSource = TranslationSource.Lines

var plugin: EditorPlugin


func _ready() -> void:
	plugin = Engine.get_meta("DialogueManagerPlugin")

	apply_theme()

	# Start with nothing open
	self.current_file_path = ""

	# Set up the update checker
	version_label.text = "v%s" % plugin.get_version()
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
	var editor_settings: EditorSettings = plugin.get_editor_interface().get_editor_settings()
	editor_settings.settings_changed.connect(_on_editor_settings_changed)
	_on_editor_settings_changed()

	# Reopen any files that were open when Godot was closed
	if editor_settings.get_setting("text_editor/behavior/files/restore_scripts_on_load"):
		var reopen_files: Array = DialogueSettings.get_user_value("reopen_files", [])
		for reopen_file in reopen_files:
			open_file(reopen_file)

		self.current_file_path = DialogueSettings.get_user_value("most_recent_reopen_file", "")

	save_all_button.disabled = true

	close_confirmation_dialog.ok_button_text = DialogueConstants.translate(&"confirm_close.save")
	close_confirmation_dialog.add_button(DialogueConstants.translate(&"confirm_close.discard"), true, "discard")

	errors_dialog.dialog_text = DialogueConstants.translate(&"errors_in_script")

	# Update the buffer if a file was modified externally (retains undo step)
	Engine.get_meta("DialogueCache").file_content_changed.connect(_on_cache_file_content_changed)

	plugin.get_editor_interface().get_file_system_dock().files_moved.connect(_on_files_moved)


func _exit_tree() -> void:
	DialogueSettings.set_user_value("reopen_files", open_buffers.keys())
	DialogueSettings.set_user_value("most_recent_reopen_file", self.current_file_path)


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return

	if event is InputEventKey and event.is_pressed():
		var shortcut: String = plugin.get_editor_shortcut(event)
		match shortcut:
			"close_file":
				get_viewport().set_input_as_handled()
				close_file(current_file_path)
			"save":
				get_viewport().set_input_as_handled()
				save_file(current_file_path)
			"find_in_files":
				get_viewport().set_input_as_handled()
				_on_find_in_files_button_pressed()
			"run_test_scene":
				get_viewport().set_input_as_handled()
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

	var interface: EditorInterface = plugin.get_editor_interface()
	if just_refreshed.current_file_path != "":
		interface.edit_resource(load(just_refreshed.current_file_path))
	else:
		interface.set_main_screen_editor("Dialogue")

	updated_dialog.dialog_text = DialogueConstants.translate(&"update.success").format({ version = update_button.get_version() })
	updated_dialog.popup_centered()


func new_file(path: String, content: String = "") -> void:
	if open_buffers.has(path):
		remove_file_from_open_buffers(path)

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if content == "":
		if DialogueSettings.get_setting("new_with_template", true):
			file.store_string(DialogueSettings.get_setting("new_template", ""))
	else:
		file.store_string(content)

	plugin.get_editor_interface().get_resource_filesystem().scan()


# Open a dialogue resource for editing
func open_resource(resource: DialogueResource) -> void:
	open_file(resource.resource_path)


func open_file(path: String) -> void:
	if not FileAccess.file_exists(path): return

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
	var file_system_dock: FileSystemDock = plugin \
		.get_editor_interface() \
		.get_file_system_dock()

	file_system_dock.navigate_to_path(path)


# Save any open files
func save_files() -> void:
	save_all_button.disabled = true

	var saved_files: PackedStringArray = []
	for path in open_buffers:
		if open_buffers[path].text != open_buffers[path].pristine_text:
			saved_files.append(path)
		save_file(path, false)

	if saved_files.size() > 0:
		Engine.get_meta("DialogueCache").reimport_files(saved_files)


# Save a file
func save_file(path: String, rescan_file_system: bool = true) -> void:
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
	file.close()

	if rescan_file_system:
		plugin \
			.get_editor_interface() \
			.get_resource_filesystem()\
			.scan()


func close_file(path: String) -> void:
	if not path in open_buffers.keys(): return

	var buffer = open_buffers[path]

	if buffer.text == buffer.pristine_text:
		remove_file_from_open_buffers(path)
		await get_tree().process_frame
	else:
		close_confirmation_dialog.dialog_text = DialogueConstants.translate(&"confirm_close").format({ path = path.get_file() })
		close_confirmation_dialog.popup_centered()
		await confirmation_closed


func remove_file_from_open_buffers(path: String) -> void:
	if not path in open_buffers.keys(): return

	var current_index = open_buffers.keys().find(current_file_path)

	open_buffers.erase(path)
	if open_buffers.size() == 0:
		self.current_file_path = ""
	else:
		current_index = clamp(current_index, 0, open_buffers.size() - 1)
		self.current_file_path = open_buffers.keys()[current_index]

	files_list.files = open_buffers.keys()


# Apply theme colors and icons to the UI
func apply_theme() -> void:
	if is_instance_valid(plugin) and is_instance_valid(code_edit):
		var scale: float = plugin.get_editor_interface().get_editor_scale()
		var editor_settings = plugin.get_editor_interface().get_editor_settings()
		code_edit.theme_overrides = {
			scale = scale,

			background_color = editor_settings.get_setting("text_editor/theme/highlighting/background_color"),
			current_line_color = editor_settings.get_setting("text_editor/theme/highlighting/current_line_color"),
			error_line_color = editor_settings.get_setting("text_editor/theme/highlighting/mark_color"),

			critical_color = editor_settings.get_setting("text_editor/theme/highlighting/comment_markers/critical_color"),
			notice_color = editor_settings.get_setting("text_editor/theme/highlighting/comment_markers/notice_color"),

			titles_color = editor_settings.get_setting("text_editor/theme/highlighting/control_flow_keyword_color"),
			text_color = editor_settings.get_setting("text_editor/theme/highlighting/text_color"),
			conditions_color = editor_settings.get_setting("text_editor/theme/highlighting/keyword_color"),
			mutations_color = editor_settings.get_setting("text_editor/theme/highlighting/function_color"),
			members_color = editor_settings.get_setting("text_editor/theme/highlighting/member_variable_color"),
			strings_color = editor_settings.get_setting("text_editor/theme/highlighting/string_color"),
			numbers_color = editor_settings.get_setting("text_editor/theme/highlighting/number_color"),
			symbols_color = editor_settings.get_setting("text_editor/theme/highlighting/symbol_color"),
			comments_color = editor_settings.get_setting("text_editor/theme/highlighting/comment_color"),
			jumps_color = Color(editor_settings.get_setting("text_editor/theme/highlighting/control_flow_keyword_color"), 0.7),

			font_size = editor_settings.get_setting("interface/editor/code_font_size")
		}

		new_button.icon = get_theme_icon("New", "EditorIcons")
		new_button.tooltip_text = DialogueConstants.translate(&"start_a_new_file")

		open_button.icon = get_theme_icon("Load", "EditorIcons")
		open_button.tooltip_text = DialogueConstants.translate(&"open_a_file")

		save_all_button.icon = get_theme_icon("Save", "EditorIcons")
		save_all_button.tooltip_text = DialogueConstants.translate(&"start_all_files")

		find_in_files_button.icon = get_theme_icon("ViewportZoom", "EditorIcons")
		find_in_files_button.tooltip_text = DialogueConstants.translate(&"find_in_files")

		test_button.icon = get_theme_icon("PlayScene", "EditorIcons")
		test_button.tooltip_text = DialogueConstants.translate(&"test_dialogue")

		search_button.icon = get_theme_icon("Search", "EditorIcons")
		search_button.tooltip_text = DialogueConstants.translate(&"search_for_text")

		insert_button.icon = get_theme_icon("RichTextEffect", "EditorIcons")
		insert_button.text = DialogueConstants.translate(&"insert")

		translations_button.icon = get_theme_icon("Translation", "EditorIcons")
		translations_button.text = DialogueConstants.translate(&"translations")

		settings_button.icon = get_theme_icon("Tools", "EditorIcons")
		settings_button.tooltip_text = DialogueConstants.translate(&"settings")

		support_button.icon = get_theme_icon("Heart", "EditorIcons")
		support_button.text = DialogueConstants.translate(&"sponsor")
		support_button.tooltip_text = DialogueConstants.translate(&"show_support")

		docs_button.icon = get_theme_icon("Help", "EditorIcons")
		docs_button.text = DialogueConstants.translate(&"docs")

		update_button.apply_theme()

		# Set up the effect menu
		var popup: PopupMenu = insert_button.get_popup()
		popup.clear()
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.wave_bbcode"), 0)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.shake_bbcode"), 1)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("Time", "EditorIcons"), DialogueConstants.translate(&"insert.typing_pause"), 3)
		popup.add_icon_item(get_theme_icon("ViewportSpeed", "EditorIcons"), DialogueConstants.translate(&"insert.typing_speed_change"), 4)
		popup.add_icon_item(get_theme_icon("DebugNext", "EditorIcons"), DialogueConstants.translate(&"insert.auto_advance"), 5)
		popup.add_separator(DialogueConstants.translate(&"insert.templates"))
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.title"), 6)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.dialogue"), 7)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.response"), 8)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.random_lines"), 9)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.random_text"), 10)
		popup.add_separator(DialogueConstants.translate(&"insert.actions"))
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.jump"), 11)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DialogueConstants.translate(&"insert.end_dialogue"), 12)

		# Set up the translations menu
		popup = translations_button.get_popup()
		popup.clear()
		popup.add_icon_item(get_theme_icon("Translation", "EditorIcons"), DialogueConstants.translate(&"generate_line_ids"), TRANSLATIONS_GENERATE_LINE_IDS)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("FileList", "EditorIcons"), DialogueConstants.translate(&"save_characters_to_csv"), TRANSLATIONS_SAVE_CHARACTERS_TO_CSV)
		popup.add_icon_item(get_theme_icon("FileList", "EditorIcons"), DialogueConstants.translate(&"save_to_csv"), TRANSLATIONS_SAVE_TO_CSV)
		popup.add_icon_item(get_theme_icon("AssetLib", "EditorIcons"), DialogueConstants.translate(&"import_from_csv"), TRANSLATIONS_IMPORT_FROM_CSV)

		# Dialog sizes
		new_dialog.min_size = Vector2(600, 500) * scale
		save_dialog.min_size = Vector2(600, 500) * scale
		open_dialog.min_size = Vector2(600, 500) * scale
		quick_open_dialog.min_size = Vector2(400, 600) * scale
		export_dialog.min_size = Vector2(600, 500) * scale
		import_dialog.min_size = Vector2(600, 500) * scale
		settings_dialog.min_size = Vector2(1000, 600) * scale
		settings_dialog.max_size = Vector2(1000, 600) * scale
		find_in_files_dialog.min_size = Vector2(800, 600) * scale


### Helpers


# Refresh the open menu with the latest files
func build_open_menu() -> void:
	var menu = open_button.get_popup()
	menu.clear()
	menu.add_icon_item(get_theme_icon("Load", "EditorIcons"), DialogueConstants.translate(&"open.open"), OPEN_OPEN)
	menu.add_icon_item(get_theme_icon("Load", "EditorIcons"), DialogueConstants.translate(&"open.quick_open"), OPEN_QUICK)
	menu.add_separator()

	var recent_files = DialogueSettings.get_recent_files()
	if recent_files.size() == 0:
		menu.add_item(DialogueConstants.translate(&"open.no_recent_files"))
		menu.set_item_disabled(2, true)
	else:
		for path in recent_files:
			if FileAccess.file_exists(path):
				menu.add_icon_item(get_theme_icon("File", "EditorIcons"), path)

	menu.add_separator()
	menu.add_item(DialogueConstants.translate(&"open.clear_recent_files"), OPEN_CLEAR)
	if menu.id_pressed.is_connected(_on_open_menu_id_pressed):
		menu.id_pressed.disconnect(_on_open_menu_id_pressed)
	menu.id_pressed.connect(_on_open_menu_id_pressed)


# Get the last place a CSV, etc was exported
func get_last_export_path(extension: String) -> String:
	var filename = current_file_path.get_file().replace(".dialogue", "." + extension)
	return DialogueSettings.get_user_value("last_export_path", current_file_path.get_base_dir()) + "/" + filename


# Check the current text for errors
func parse() -> void:
	# Skip if nothing to parse
	if current_file_path == "": return

	var parser = DialogueManagerParser.new()
	var errors: Array[Dictionary] = []
	if parser.parse(code_edit.text, current_file_path) != OK:
		errors = parser.get_errors()
	code_edit.errors = errors
	errors_panel.errors = errors
	parser.free()


func show_build_error_dialog() -> void:
	build_error_dialog.dialog_text = DialogueConstants.translate(&"errors_with_build")
	build_error_dialog.popup_centered()


# Generate translation line IDs for any line that doesn't already have one
func generate_translations_keys() -> void:
	randomize()
	seed(Time.get_unix_time_from_system())

	var parser = DialogueManagerParser.new()

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
		if parser.is_import_line(l): continue

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


# Add a translation file to the project settings
func add_path_to_project_translations(path: String) -> void:
	var translations: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations")
	if not path in translations:
		translations.append(path)
		ProjectSettings.save()


# Export dialogue and responses to CSV
func export_translations_to_csv(path: String) -> void:
	var default_locale: String = DialogueSettings.get_setting("default_csv_locale", "en")

	var file: FileAccess

	# If the file exists, open it first and work out which keys are already in it
	var existing_csv: Dictionary = {}
	var column_count: int = 2
	var default_locale_column: int = 1
	var character_column: int = -1
	var notes_column: int = -1
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ)
		var is_first_line = true
		var line: Array
		while !file.eof_reached():
			line = file.get_csv_line()
			if is_first_line:
				is_first_line = false
				column_count = line.size()
				for i in range(1, line.size()):
					if line[i] == default_locale:
						default_locale_column = i
					elif line[i] == "_character":
						character_column = i
					elif line[i] == "_notes":
						notes_column = i

			# Make sure the line isn't empty before adding it
			if line.size() > 0 and line[0].strip_edges() != "":
				existing_csv[line[0]] = line

		# The character column wasn't found in the existing file but the setting is turned on
		if character_column == -1 and DialogueSettings.get_setting("include_character_in_translation_exports", false):
			character_column = column_count
			column_count += 1
			existing_csv["keys"].append("_character")

		# The notes column wasn't found in the existing file but the setting is turned on
		if notes_column == -1 and DialogueSettings.get_setting("include_notes_in_translation_exports", false):
			notes_column = column_count
			column_count += 1
			existing_csv["keys"].append("_notes")

	# Start a new file
	file = FileAccess.open(path, FileAccess.WRITE)

	if not FileAccess.file_exists(path):
		var headings: PackedStringArray = ["keys", default_locale]
		if DialogueSettings.get_setting("include_character_in_translation_exports", false):
			character_column = headings.size()
			headings.append("_character")
		if DialogueSettings.get_setting("include_notes_in_translation_exports", false):
			notes_column = headings.size()
			headings.append("_notes")
		file.store_csv_line(headings)
		column_count = headings.size()

	# Write our translations to file
	var known_keys: PackedStringArray = []

	var dialogue: Dictionary = DialogueManagerParser.parse_string(code_edit.text, current_file_path).lines

	# Make a list of stuff that needs to go into the file
	var lines_to_save = []
	for key in dialogue.keys():
		var line: Dictionary = dialogue.get(key)

		if not line.type in [DialogueConstants.TYPE_DIALOGUE, DialogueConstants.TYPE_RESPONSE]: continue
		if line.translation_key in known_keys: continue

		known_keys.append(line.translation_key)

		var line_to_save: PackedStringArray = []
		if existing_csv.has(line.translation_key):
			line_to_save = existing_csv.get(line.translation_key)
			line_to_save.resize(column_count)
			existing_csv.erase(line.translation_key)
		else:
			line_to_save.resize(column_count)
			line_to_save[0] = line.translation_key

		line_to_save[default_locale_column] = line.text
		if character_column > -1:
			line_to_save[character_column] = "(response)" if line.type == DialogueConstants.TYPE_RESPONSE else line.character
		if notes_column > -1:
			line_to_save[notes_column] = line.notes

		lines_to_save.append(line_to_save)

	# Store lines in the file, starting with anything that already exists that hasn't been touched
	for line in existing_csv.values():
		file.store_csv_line(line)
	for line in lines_to_save:
		file.store_csv_line(line)

	file.close()

	plugin.get_editor_interface().get_resource_filesystem().scan()
	plugin.get_editor_interface().get_file_system_dock().call_deferred("navigate_to_path", path)

	# Add it to the project l10n settings if it's not already there
	var language_code: RegExMatch = RegEx.create_from_string("^[a-z]{2,3}").search(default_locale)
	var translation_path: String = path.replace(".csv", ".%s.translation" % language_code.get_string())
	call_deferred("add_path_to_project_translations", translation_path)


func export_character_names_to_csv(path: String) -> void:
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
		file.store_csv_line(["keys", DialogueSettings.get_setting("default_csv_locale", "en")])

	# Write our translations to file
	var known_keys: PackedStringArray = []

	var character_names: PackedStringArray = DialogueManagerParser.parse_string(code_edit.text, current_file_path).character_names

	# Make a list of stuff that needs to go into the file
	var lines_to_save = []
	for character_name in character_names:
		if character_name in known_keys: continue

		known_keys.append(character_name)

		if existing_csv.has(character_name):
			var existing_line = existing_csv.get(character_name)
			existing_line[1] = character_name
			lines_to_save.append(existing_line)
			existing_csv.erase(character_name)
		else:
			lines_to_save.append(PackedStringArray([character_name, character_name] + commas))

	# Store lines in the file, starting with anything that already exists that hasn't been touched
	for line in existing_csv.values():
		file.store_csv_line(line)
	for line in lines_to_save:
		file.store_csv_line(line)

	file.close()

	plugin.get_editor_interface().get_resource_filesystem().scan()
	plugin.get_editor_interface().get_file_system_dock().call_deferred("navigate_to_path", path)

	# Add it to the project l10n settings if it's not already there
	var translation_path: String = path.replace(".csv", ".en.translation")
	call_deferred("add_path_to_project_translations", translation_path)


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

	var parser: DialogueManagerParser = DialogueManagerParser.new()

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


func show_search_form(is_enabled: bool) -> void:
	if code_edit.last_selected_text:
		search_and_replace.input.text = code_edit.last_selected_text

	search_and_replace.visible = is_enabled
	search_button.set_pressed_no_signal(is_enabled)
	search_and_replace.focus_line_edit()


### Signals


func _on_files_moved(old_file: String, new_file: String) -> void:
	if open_buffers.has(old_file):
		open_buffers[new_file] = open_buffers[old_file]
		open_buffers.erase(old_file)
		open_buffers[new_file]


func _on_cache_file_content_changed(path: String, new_content: String) -> void:
	if open_buffers.has(path):
		var buffer = open_buffers[path]
		if buffer.text != new_content:
			buffer.text = new_content
			buffer.pristine_text = new_content
			code_edit.text = new_content


func _on_editor_settings_changed() -> void:
	var editor_settings: EditorSettings = plugin.get_editor_interface().get_editor_settings()
	code_edit.minimap_draw = editor_settings.get_setting("text_editor/appearance/minimap/show_minimap")
	code_edit.minimap_width = editor_settings.get_setting("text_editor/appearance/minimap/minimap_width")
	code_edit.scroll_smooth = editor_settings.get_setting("text_editor/behavior/navigation/smooth_scrolling")


func _on_open_menu_id_pressed(id: int) -> void:
	match id:
		OPEN_OPEN:
			open_dialog.popup_centered()
		OPEN_QUICK:
			quick_open_files_list.files = Engine.get_meta("DialogueCache").get_files()
			quick_open_dialog.popup_centered()
			quick_open_files_list.focus_filter()
		OPEN_CLEAR:
			DialogueSettings.clear_recent_files()
			build_open_menu()
		_:
			var menu = open_button.get_popup()
			var item = menu.get_item_text(menu.get_item_index(id))
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
			code_edit.insert_text_at_cursor("~ title")
		7:
			code_edit.insert_text_at_cursor("Nathan: This is Some Dialogue")
		8:
			code_edit.insert_text_at_cursor("Nathan: Choose a Response...\n- Option 1\n\tNathan: You chose option 1\n- Option 2\n\tNathan: You chose option 2")
		9:
			code_edit.insert_text_at_cursor("% Nathan: This is random line 1.\n% Nathan: This is random line 2.\n%1 Nathan: This is weighted random line 3.")
		10:
			code_edit.insert_text_at_cursor("Nathan: [[Hi|Hello|Howdy]]")
		11:
			code_edit.insert_text_at_cursor("=> title")
		12:
			code_edit.insert_text_at_cursor("=> END")


func _on_translations_button_menu_id_pressed(id: int) -> void:
	match id:
		TRANSLATIONS_GENERATE_LINE_IDS:
			generate_translations_keys()

		TRANSLATIONS_SAVE_CHARACTERS_TO_CSV:
			translation_source = TranslationSource.CharacterNames
			export_dialog.filters = PackedStringArray(["*.csv ; Translation CSV"])
			export_dialog.current_path = get_last_export_path("csv")
			export_dialog.popup_centered()

		TRANSLATIONS_SAVE_TO_CSV:
			translation_source = TranslationSource.Lines
			export_dialog.filters = PackedStringArray(["*.csv ; Translation CSV"])
			export_dialog.current_path = get_last_export_path("csv")
			export_dialog.popup_centered()

		TRANSLATIONS_IMPORT_FROM_CSV:
			import_dialog.current_path = get_last_export_path("csv")
			import_dialog.popup_centered()


func _on_export_dialog_file_selected(path: String) -> void:
	DialogueSettings.set_user_value("last_export_path", path.get_base_dir())
	match path.get_extension():
		"csv":
			match translation_source:
				TranslationSource.CharacterNames:
					export_character_names_to_csv(path)
				TranslationSource.Lines:
					export_translations_to_csv(path)


func _on_import_dialog_file_selected(path: String) -> void:
	DialogueSettings.set_user_value("last_export_path", path.get_base_dir())
	import_translations_from_csv(path)


func _on_main_view_theme_changed():
	apply_theme()


func _on_main_view_visibility_changed() -> void:
	if visible and is_instance_valid(code_edit):
		code_edit.grab_focus()


func _on_new_button_pressed() -> void:
	new_dialog.current_file = "dialogue"
	new_dialog.popup_centered()


func _on_new_dialog_confirmed() -> void:
	if new_dialog.current_file.get_basename() == "":
		var path = "res://untitled.dialogue"
		new_file(path)
		open_file(path)


func _on_new_dialog_file_selected(path: String) -> void:
	new_file(path)
	open_file(path)


func _on_save_dialog_file_selected(path: String) -> void:
	if path == "": path = "res://untitled.dialogue"

	new_file(path, code_edit.text)
	open_file(path)


func _on_open_button_about_to_popup() -> void:
	build_open_menu()


func _on_open_dialog_file_selected(path: String) -> void:
	open_file(path)


func _on_quick_open_files_list_file_double_clicked(file_path: String) -> void:
	quick_open_dialog.hide()
	open_file(file_path)


func _on_quick_open_dialog_confirmed() -> void:
	if quick_open_files_list.current_file_path:
		open_file(quick_open_files_list.current_file_path)


func _on_save_all_button_pressed() -> void:
	save_files()


func _on_find_in_files_button_pressed() -> void:
	find_in_files_dialog.popup_centered()
	find_in_files.prepare()


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


func _on_errors_panel_error_pressed(line_number: int, column_number: int) -> void:
	code_edit.set_caret_line(line_number)
	code_edit.set_caret_column(column_number)
	code_edit.grab_focus()


func _on_search_button_toggled(button_pressed: bool) -> void:
	show_search_form(button_pressed)


func _on_search_and_replace_open_requested() -> void:
	show_search_form(true)


func _on_search_and_replace_close_requested() -> void:
	search_button.set_pressed_no_signal(false)
	search_and_replace.visible = false
	code_edit.grab_focus()


func _on_settings_button_pressed() -> void:
	settings_view.prepare()
	settings_dialog.popup_centered()


func _on_settings_view_script_button_pressed(path: String) -> void:
	settings_dialog.hide()
	plugin.get_editor_interface().edit_resource(load(path))


func _on_test_button_pressed() -> void:
	save_file(current_file_path)

	if errors_panel.errors.size() > 0:
		errors_dialog.popup_centered()
		return

	DialogueSettings.set_user_value("is_running_test_scene", true)
	DialogueSettings.set_user_value("run_resource_path", current_file_path)
	var test_scene_path: String = DialogueSettings.get_setting("custom_test_scene_path", "res://addons/dialogue_manager/test_scene.tscn")
	plugin.get_editor_interface().play_custom_scene(test_scene_path)


func _on_settings_dialog_confirmed() -> void:
	settings_view.apply_settings_changes()
	parse()
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if DialogueSettings.get_setting("wrap_lines", false) else TextEdit.LINE_WRAPPING_NONE
	code_edit.grab_focus()


func _on_support_button_pressed() -> void:
	OS.shell_open("https://patreon.com/nathanhoad")


func _on_docs_button_pressed() -> void:
	OS.shell_open("https://github.com/nathanhoad/godot_dialogue_manager")


func _on_files_list_file_popup_menu_requested(at_position: Vector2) -> void:
	files_popup_menu.position = Vector2(get_viewport().position) + files_list.global_position + at_position
	files_popup_menu.popup()


func _on_files_list_file_middle_clicked(path: String):
	close_file(path)


func _on_files_popup_menu_about_to_popup() -> void:
	files_popup_menu.clear()

	var shortcuts: Dictionary = plugin.get_editor_shortcuts()

	files_popup_menu.add_item(DialogueConstants.translate(&"buffer.save"), ITEM_SAVE, OS.find_keycode_from_string(shortcuts.get("save")[0].as_text_keycode()))
	files_popup_menu.add_item(DialogueConstants.translate(&"buffer.save_as"), ITEM_SAVE_AS)
	files_popup_menu.add_item(DialogueConstants.translate(&"buffer.close"), ITEM_CLOSE, OS.find_keycode_from_string(shortcuts.get("close_file")[0].as_text_keycode()))
	files_popup_menu.add_item(DialogueConstants.translate(&"buffer.close_all"), ITEM_CLOSE_ALL)
	files_popup_menu.add_item(DialogueConstants.translate(&"buffer.close_other_files"), ITEM_CLOSE_OTHERS)
	files_popup_menu.add_separator()
	files_popup_menu.add_item(DialogueConstants.translate(&"buffer.copy_file_path"), ITEM_COPY_PATH)
	files_popup_menu.add_item(DialogueConstants.translate(&"buffer.show_in_filesystem"), ITEM_SHOW_IN_FILESYSTEM)


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
			var current_current_file_path: String = current_file_path
			for path in open_buffers.keys():
				if path != current_current_file_path:
					await close_file(path)

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
	confirmation_closed.emit()


func _on_close_confirmation_dialog_custom_action(action: StringName) -> void:
	if action == "discard":
		remove_file_from_open_buffers(current_file_path)
	close_confirmation_dialog.hide()
	confirmation_closed.emit()


func _on_find_in_files_result_selected(path: String, cursor: Vector2, length: int) -> void:
	open_file(path)
	code_edit.select(cursor.y, cursor.x, cursor.y, cursor.x + length)

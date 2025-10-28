@tool
extends Control


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


@onready var parse_timer: Timer = $ParseTimer

# Banner
@onready var banner: CenterContainer = %Banner
@onready var banner_new_button: Button = %BannerNewButton
@onready var banner_quick_open: Button = %BannerQuickOpen
@onready var banner_examples: Button = %BannerExamples

# Dialogs
@onready var new_dialog: FileDialog = $NewDialog
@onready var save_dialog: FileDialog = $SaveDialog
@onready var open_dialog: FileDialog = $OpenDialog
@onready var quick_open_dialog: ConfirmationDialog = $QuickOpenDialog
@onready var quick_open_files_list: VBoxContainer = $QuickOpenDialog/QuickOpenFilesList
@onready var export_dialog: FileDialog = $ExportDialog
@onready var import_dialog: FileDialog = $ImportDialog
@onready var errors_dialog: AcceptDialog = $ErrorsDialog
@onready var build_error_dialog: AcceptDialog = $BuildErrorDialog
@onready var close_confirmation_dialog: ConfirmationDialog = $CloseConfirmationDialog
@onready var updated_dialog: AcceptDialog = $UpdatedDialog

# Toolbar
@onready var new_button: Button = %NewButton
@onready var open_button: MenuButton = %OpenButton
@onready var save_all_button: Button = %SaveAllButton
@onready var find_in_files_button: Button = %FindInFilesButton
@onready var test_button: Button = %TestButton
@onready var test_line_button: Button = %TestLineButton
@onready var search_button: Button = %SearchButton
@onready var insert_button: MenuButton = %InsertButton
@onready var translations_button: MenuButton = %TranslationsButton
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
@onready var code_edit: DMCodeEdit = %CodeEdit
@onready var errors_panel := %ErrorsPanel

# The currently open file
var current_file_path: String = "":
	set(next_current_file_path):
		current_file_path = next_current_file_path
		files_list.current_file_path = current_file_path
		if current_file_path == "" or not open_buffers.has(current_file_path):
			save_all_button.disabled = true
			test_button.disabled = true
			test_line_button.disabled = true
			search_button.disabled = true
			insert_button.disabled = true
			translations_button.disabled = true
			content.dragger_visibility = SplitContainer.DRAGGER_HIDDEN
			files_list.hide()
			title_list.hide()
			code_edit.hide()
			errors_panel.hide()
			search_and_replace.hide()
			banner.show()
		else:
			test_button.disabled = false
			test_line_button.disabled = false
			search_button.disabled = false
			insert_button.disabled = false
			translations_button.disabled = false
			content.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
			files_list.show()
			title_list.show()
			code_edit.show()
			banner.hide()

			var cursor: Vector2 = DMSettings.get_caret(current_file_path)
			var scroll_vertical: int = DMSettings.get_scroll(current_file_path)

			code_edit.text = open_buffers[current_file_path].text
			code_edit.errors = []
			code_edit.clear_undo_history()
			code_edit.set_cursor(cursor)
			code_edit.scroll_vertical = scroll_vertical
			code_edit.grab_focus()

			_on_code_edit_text_changed()

			errors_panel.errors = []
			code_edit.errors = []

			if search_and_replace.visible:
				search_and_replace.search()
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
		DMSettings.set_user_value("just_refreshed", {
			current_file_path = current_file_path,
			open_buffers = open_buffers
		})
		return true

	# Did we just load from an addon version refresh?
	var just_refreshed = DMSettings.get_user_value("just_refreshed", null)
	if just_refreshed != null:
		DMSettings.set_user_value("just_refreshed", null)
		call_deferred("load_from_version_refresh", just_refreshed)

	# Hook up the search toolbar
	search_and_replace.code_edit = code_edit

	# Connect menu buttons
	insert_button.get_popup().id_pressed.connect(_on_insert_button_menu_id_pressed)
	translations_button.get_popup().id_pressed.connect(_on_translations_button_menu_id_pressed)

	code_edit.main_view = self
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	editor_settings.settings_changed.connect(_on_editor_settings_changed)
	_on_editor_settings_changed()

	ProjectSettings.settings_changed.connect(_on_project_settings_changed)
	_on_project_settings_changed()

	# Reopen any files that were open when Godot was closed
	if editor_settings.get_setting("text_editor/behavior/files/restore_scripts_on_load"):
		var reopen_files: Array = DMSettings.get_user_value("reopen_files", [])
		for reopen_file in reopen_files:
			open_file(reopen_file)

		self.current_file_path = DMSettings.get_user_value("most_recent_reopen_file", "")

	save_all_button.disabled = true

	close_confirmation_dialog.ok_button_text = DMConstants.translate(&"confirm_close.save")
	close_confirmation_dialog.add_button(DMConstants.translate(&"confirm_close.discard"), true, "discard")

	errors_dialog.dialog_text = DMConstants.translate(&"errors_in_script")

	# Update the buffer if a file was modified externally (retains undo step)
	Engine.get_meta("DMCache").file_content_changed.connect(_on_cache_file_content_changed)

	EditorInterface.get_file_system_dock().files_moved.connect(_on_files_moved)

	code_edit.get_v_scroll_bar().value_changed.connect(_on_code_edit_scroll_changed)


func _exit_tree() -> void:
	DMSettings.set_user_value("reopen_files", open_buffers.keys())
	DMSettings.set_user_value("most_recent_reopen_file", self.current_file_path)


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

	if just_refreshed.current_file_path != "":
		EditorInterface.edit_resource(load(just_refreshed.current_file_path))
	else:
		EditorInterface.set_main_screen_editor("Dialogue")

	updated_dialog.dialog_text = DMConstants.translate(&"update.success").format({ version = update_button.get_version() })
	updated_dialog.popup_centered()


func new_file(path: String, content: String = "") -> void:
	if open_buffers.has(path):
		remove_file_from_open_buffers(path)

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if content == "":
		file.store_string(DMSettings.get_setting(DMSettings.NEW_FILE_TEMPLATE, ""))
	else:
		file.store_string(content)

	EditorInterface.get_resource_filesystem().scan()


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

	DMSettings.add_recent_file(path)
	build_open_menu()

	files_list.files = open_buffers.keys()
	files_list.select_file(path)

	self.current_file_path = path


func quick_open() -> void:
	quick_open_files_list.files = Engine.get_meta("DMCache").get_files()
	quick_open_dialog.popup_centered()
	quick_open_files_list.focus_filter()


func show_file_in_filesystem(path: String) -> void:
	EditorInterface.get_file_system_dock().navigate_to_path(path)


# Save any open files
func save_files() -> void:
	save_all_button.disabled = true

	var saved_files: PackedStringArray = []
	for path in open_buffers:
		if open_buffers[path].text != open_buffers[path].pristine_text:
			saved_files.append(path)
		save_file(path, false)

	if saved_files.size() > 0:
		Engine.get_meta("DMCache").mark_files_for_reimport(saved_files)


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
		EditorInterface.get_resource_filesystem().scan()


func close_file(path: String) -> void:
	if not path in open_buffers.keys(): return

	var buffer = open_buffers[path]

	if buffer.text == buffer.pristine_text:
		remove_file_from_open_buffers(path)
		await get_tree().process_frame
	else:
		close_confirmation_dialog.dialog_text = DMConstants.translate(&"confirm_close").format({ path = path.get_file() })
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
		var scale: float = EditorInterface.get_editor_scale()
		var editor_settings = EditorInterface.get_editor_settings()
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
			mutations_line_color = Color(editor_settings.get_setting("text_editor/theme/highlighting/function_color"), 0.6),
			members_color = editor_settings.get_setting("text_editor/theme/highlighting/member_variable_color"),
			strings_color = editor_settings.get_setting("text_editor/theme/highlighting/string_color"),
			numbers_color = editor_settings.get_setting("text_editor/theme/highlighting/number_color"),
			symbols_color = editor_settings.get_setting("text_editor/theme/highlighting/symbol_color"),
			comments_color = editor_settings.get_setting("text_editor/theme/highlighting/comment_color"),
			jumps_color = Color(editor_settings.get_setting("text_editor/theme/highlighting/control_flow_keyword_color"), 0.6),

			font_size = editor_settings.get_setting("interface/editor/code_font_size")
		}

		banner_new_button.icon = get_theme_icon("New", "EditorIcons")
		banner_quick_open.icon = get_theme_icon("Load", "EditorIcons")

		new_button.icon = get_theme_icon("New", "EditorIcons")
		new_button.tooltip_text = DMConstants.translate(&"start_a_new_file")

		open_button.icon = get_theme_icon("Load", "EditorIcons")
		open_button.tooltip_text = DMConstants.translate(&"open_a_file")

		save_all_button.icon = get_theme_icon("Save", "EditorIcons")
		save_all_button.text = DMConstants.translate(&"all")
		save_all_button.tooltip_text = DMConstants.translate(&"start_all_files")

		find_in_files_button.icon = get_theme_icon("ViewportZoom", "EditorIcons")
		find_in_files_button.tooltip_text = DMConstants.translate(&"find_in_files")

		test_button.icon = get_theme_icon("DebugNext", "EditorIcons")
		test_button.tooltip_text = DMConstants.translate(&"test_dialogue")

		test_line_button.icon = get_theme_icon("DebugStep", "EditorIcons")
		test_line_button.tooltip_text = DMConstants.translate(&"test_dialogue_from_line")

		search_button.icon = get_theme_icon("Search", "EditorIcons")
		search_button.tooltip_text = DMConstants.translate(&"search_for_text")

		insert_button.icon = get_theme_icon("RichTextEffect", "EditorIcons")
		insert_button.text = DMConstants.translate(&"insert")

		translations_button.icon = get_theme_icon("Translation", "EditorIcons")
		translations_button.text = DMConstants.translate(&"translations")

		support_button.icon = get_theme_icon("Heart", "EditorIcons")
		support_button.text = DMConstants.translate(&"sponsor")
		support_button.tooltip_text = DMConstants.translate(&"show_support")

		docs_button.icon = get_theme_icon("Help", "EditorIcons")
		docs_button.text = DMConstants.translate(&"docs")

		update_button.apply_theme()

		# Set up the effect menu
		var popup: PopupMenu = insert_button.get_popup()
		popup.clear()
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.wave_bbcode"), 0)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.shake_bbcode"), 1)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("Time", "EditorIcons"), DMConstants.translate(&"insert.typing_pause"), 3)
		popup.add_icon_item(get_theme_icon("ViewportSpeed", "EditorIcons"), DMConstants.translate(&"insert.typing_speed_change"), 4)
		popup.add_icon_item(get_theme_icon("DebugNext", "EditorIcons"), DMConstants.translate(&"insert.auto_advance"), 5)
		popup.add_separator(DMConstants.translate(&"insert.templates"))
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.title"), 6)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.dialogue"), 7)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.response"), 8)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.random_lines"), 9)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.random_text"), 10)
		popup.add_separator(DMConstants.translate(&"insert.actions"))
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.jump"), 11)
		popup.add_icon_item(get_theme_icon("RichTextEffect", "EditorIcons"), DMConstants.translate(&"insert.end_dialogue"), 12)

		# Set up the translations menu
		popup = translations_button.get_popup()
		popup.clear()
		popup.add_icon_item(get_theme_icon("Translation", "EditorIcons"), DMConstants.translate(&"generate_line_ids"), TRANSLATIONS_GENERATE_LINE_IDS)
		popup.add_separator()
		popup.add_icon_item(get_theme_icon("FileList", "EditorIcons"), DMConstants.translate(&"save_characters_to_csv"), TRANSLATIONS_SAVE_CHARACTERS_TO_CSV)
		popup.add_icon_item(get_theme_icon("FileList", "EditorIcons"), DMConstants.translate(&"save_to_csv"), TRANSLATIONS_SAVE_TO_CSV)
		popup.add_icon_item(get_theme_icon("AssetLib", "EditorIcons"), DMConstants.translate(&"import_from_csv"), TRANSLATIONS_IMPORT_FROM_CSV)

		# Dialog sizes
		new_dialog.min_size = Vector2(600, 500) * scale
		save_dialog.min_size = Vector2(600, 500) * scale
		open_dialog.min_size = Vector2(600, 500) * scale
		quick_open_dialog.min_size = Vector2(400, 600) * scale
		export_dialog.min_size = Vector2(600, 500) * scale
		import_dialog.min_size = Vector2(600, 500) * scale


### Helpers


# Refresh the open menu with the latest files
func build_open_menu() -> void:
	var menu = open_button.get_popup()
	menu.clear()
	menu.add_icon_item(get_theme_icon("Load", "EditorIcons"), DMConstants.translate(&"open.open"), OPEN_OPEN)
	menu.add_icon_item(get_theme_icon("Load", "EditorIcons"), DMConstants.translate(&"open.quick_open"), OPEN_QUICK)
	menu.add_separator()

	var recent_files = DMSettings.get_recent_files()
	if recent_files.size() == 0:
		menu.add_item(DMConstants.translate(&"open.no_recent_files"))
		menu.set_item_disabled(2, true)
	else:
		for path in recent_files:
			if FileAccess.file_exists(path):
				menu.add_icon_item(get_theme_icon("File", "EditorIcons"), path)

	menu.add_separator()
	menu.add_item(DMConstants.translate(&"open.clear_recent_files"), OPEN_CLEAR)
	if menu.id_pressed.is_connected(_on_open_menu_id_pressed):
		menu.id_pressed.disconnect(_on_open_menu_id_pressed)
	menu.id_pressed.connect(_on_open_menu_id_pressed)


# Get the last place a CSV, etc was exported
func get_last_export_path(extension: String) -> String:
	var filename = current_file_path.get_file().replace(".dialogue", "." + extension)
	return DMSettings.get_user_value("last_export_path", current_file_path.get_base_dir()) + "/" + filename


# Check the current text for errors
func compile() -> void:
	# Skip if nothing to parse
	if current_file_path == "": return

	var result: DMCompilerResult = DMCompiler.compile_string(code_edit.text, current_file_path)
	code_edit.errors = result.errors
	errors_panel.errors = result.errors
	title_list.titles = code_edit.get_titles()


func show_build_error_dialog() -> void:
	build_error_dialog.dialog_text = DMConstants.translate(&"errors_with_build")
	build_error_dialog.popup_centered()


# Generate translation line IDs for any line that doesn't already have one
func generate_translations_keys() -> void:
	var cursor: Vector2 = code_edit.get_cursor()
	var scroll_vertical = code_edit.scroll_vertical
	code_edit.text = DMTranslationUtilities.generate_translation_keys(code_edit.text)
	code_edit.set_cursor(cursor)
	code_edit.scroll_vertical = scroll_vertical
	_on_code_edit_text_changed()


# Add a translation file to the project settings
func add_path_to_project_translations(path: String) -> void:
	var translations: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations")
	if not path in translations:
		translations.append(path)
		ProjectSettings.save()


# Export dialogue and responses to CSV
func export_translations_to_csv(path: String) -> void:
	DMTranslationUtilities.export_translations_to_csv(path, code_edit.text, current_file_path)

	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.get_file_system_dock().call_deferred("navigate_to_path", path)

	# Add it to the project l10n settings if it's not already there
	var default_locale: String = DMSettings.get_setting(DMSettings.DEFAULT_CSV_LOCALE, "en")
	var language_code: RegExMatch = RegEx.create_from_string("^[a-z]{2,3}").search(default_locale)
	var translation_path: String = path.replace(".csv", ".%s.translation" % language_code.get_string())
	call_deferred("add_path_to_project_translations", translation_path)


func export_character_names_to_csv(path: String) -> void:
	DMTranslationUtilities.export_character_names_to_csv(path, code_edit.text, current_file_path)

	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.get_file_system_dock().call_deferred("navigate_to_path", path)

	# Add it to the project l10n settings if it's not already there
	var translation_path: String = path.replace(".csv", ".en.translation")
	call_deferred("add_path_to_project_translations", translation_path)


# Import changes back from an exported CSV by matching translation keys
func import_translations_from_csv(path: String) -> void:
	var cursor: Vector2 = code_edit.get_cursor()
	code_edit.text = DMTranslationUtilities.import_translations_from_csv(path, code_edit.text)
	code_edit.set_cursor(cursor)


func show_search_form(is_enabled: bool) -> void:
	if code_edit.last_selected_text:
		search_and_replace.input.text = code_edit.last_selected_text

	search_and_replace.visible = is_enabled
	search_button.set_pressed_no_signal(is_enabled)
	search_and_replace.focus_line_edit()


func run_test_scene(from_key: String) -> void:
	DMSettings.set_user_value("run_title", from_key)
	DMSettings.set_user_value("is_running_test_scene", true)
	DMSettings.set_user_value("run_resource_path", current_file_path)
	var test_scene_path: String = DMSettings.get_setting(DMSettings.CUSTOM_TEST_SCENE_PATH, "res://addons/dialogue_manager/test_scene.tscn")
	if ResourceUID.has_id(ResourceUID.text_to_id(test_scene_path)):
		test_scene_path = ResourceUID.get_id_path(ResourceUID.text_to_id(test_scene_path))
	EditorInterface.play_custom_scene(test_scene_path)


### Signals


func _on_files_moved(old_file: String, new_file: String) -> void:
	if open_buffers.has(old_file):
		open_buffers[new_file] = open_buffers[old_file]
		open_buffers.erase(old_file)
		open_buffers[new_file]


func _on_cache_file_content_changed(path: String, new_content: String) -> void:
	if open_buffers.has(path):
		var buffer = open_buffers[path]
		if buffer.text == buffer.pristine_text and buffer.text != new_content:
			buffer.text = new_content
			code_edit.text = new_content
			title_list.titles = code_edit.get_titles()
		buffer.pristine_text = new_content


func _on_editor_settings_changed() -> void:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	code_edit.minimap_draw = editor_settings.get_setting("text_editor/appearance/minimap/show_minimap")
	code_edit.minimap_width = editor_settings.get_setting("text_editor/appearance/minimap/minimap_width")
	code_edit.scroll_smooth = editor_settings.get_setting("text_editor/behavior/navigation/smooth_scrolling")


func _on_project_settings_changed() -> void:
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if DMSettings.get_setting(DMSettings.WRAP_LONG_LINES, false) else TextEdit.LINE_WRAPPING_NONE


func _on_open_menu_id_pressed(id: int) -> void:
	match id:
		OPEN_OPEN:
			open_dialog.popup_centered()
		OPEN_QUICK:
			quick_open()
		OPEN_CLEAR:
			DMSettings.clear_recent_files()
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
	DMSettings.set_user_value("last_export_path", path.get_base_dir())
	match path.get_extension():
		"csv":
			match translation_source:
				TranslationSource.CharacterNames:
					export_character_names_to_csv(path)
				TranslationSource.Lines:
					export_translations_to_csv(path)


func _on_import_dialog_file_selected(path: String) -> void:
	DMSettings.set_user_value("last_export_path", path.get_base_dir())
	import_translations_from_csv(path)


func _on_main_view_theme_changed():
	apply_theme()


func _on_main_view_visibility_changed() -> void:
	if visible and is_instance_valid(code_edit):
		code_edit.grab_focus()


func _on_new_button_pressed() -> void:
	new_dialog.current_file = "untitled"
	new_dialog.popup_centered()


func _on_new_dialog_confirmed() -> void:
	var path: String = new_dialog.current_path
	if path.get_file() == ".dialogue":
		path = "%s/untitled.dialogue" % path.get_basename()
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
	if quick_open_files_list.last_selected_file_path:
		open_file(quick_open_files_list.last_selected_file_path)


func _on_save_all_button_pressed() -> void:
	save_files()


func _on_find_in_files_button_pressed() -> void:
	plugin.show_find_in_dialogue()


func _on_code_edit_text_changed() -> void:
	var buffer = open_buffers[current_file_path]
	buffer.text = code_edit.text

	files_list.mark_file_as_unsaved(current_file_path, buffer.text != buffer.pristine_text)
	save_all_button.disabled = open_buffers.values().filter(func(d): return d.text != d.pristine_text).size() == 0

	parse_timer.start(1)


func _on_code_edit_scroll_changed(value: int) -> void:
	DMSettings.set_scroll(current_file_path, code_edit.scroll_vertical)


func _on_code_edit_active_title_change(title: String) -> void:
	title_list.select_title(title)


func _on_code_edit_caret_changed() -> void:
	DMSettings.set_caret(current_file_path, code_edit.get_cursor())


func _on_code_edit_error_clicked(line_number: int) -> void:
	errors_panel.show_error_for_line_number(line_number)


func _on_title_list_title_selected(title: String) -> void:
	code_edit.go_to_title(title)
	code_edit.grab_focus()


func _on_parse_timer_timeout() -> void:
	parse_timer.stop()
	compile()


func _on_errors_panel_error_pressed(line_number: int, column_number: int) -> void:
	code_edit.set_caret_line(line_number - 1)
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


func _on_test_button_pressed() -> void:
	save_file(current_file_path, false)
	Engine.get_meta("DMCache").reimport_files([current_file_path])

	if errors_panel.errors.size() > 0:
		errors_dialog.popup_centered()
		return

	run_test_scene("")


func _on_test_line_button_pressed() -> void:
	save_file(current_file_path)

	if errors_panel.errors.size() > 0:
		errors_dialog.popup_centered()
		return

	# Find next non-empty line
	var line_to_run: int = 0
	for i in range(code_edit.get_cursor().y, code_edit.get_line_count()):
		if not code_edit.get_line(i).is_empty():
			line_to_run = i
			break

	run_test_scene(str(line_to_run))


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

	files_popup_menu.add_item(DMConstants.translate(&"buffer.save"), ITEM_SAVE, OS.find_keycode_from_string(shortcuts.get("save")[0].as_text_keycode()))
	files_popup_menu.add_item(DMConstants.translate(&"buffer.save_as"), ITEM_SAVE_AS)
	files_popup_menu.add_item(DMConstants.translate(&"buffer.close"), ITEM_CLOSE, OS.find_keycode_from_string(shortcuts.get("close_file")[0].as_text_keycode()))
	files_popup_menu.add_item(DMConstants.translate(&"buffer.close_all"), ITEM_CLOSE_ALL)
	files_popup_menu.add_item(DMConstants.translate(&"buffer.close_other_files"), ITEM_CLOSE_OTHERS)
	files_popup_menu.add_separator()
	files_popup_menu.add_item(DMConstants.translate(&"buffer.copy_file_path"), ITEM_COPY_PATH)
	files_popup_menu.add_item(DMConstants.translate(&"buffer.show_in_filesystem"), ITEM_SHOW_IN_FILESYSTEM)


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
	code_edit.set_line_as_center_visible(cursor.y)


func _on_banner_image_gui_input(event:  InputEvent) -> void:
	if event.is_pressed():
		OS.shell_open("https://bravestcoconut.com/wishlist")


func _on_banner_new_button_pressed() -> void:
	new_dialog.current_file = "untitled"
	new_dialog.popup_centered()


func _on_banner_quick_open_pressed() -> void:
	quick_open()


func _on_banner_examples_pressed() -> void:
	OS.shell_open("https://itch.io/c/5226650/godot-dialogue-manager-example-projects")

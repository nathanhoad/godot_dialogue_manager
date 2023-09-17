@tool
extends EditorPlugin


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueImportPlugin = preload("res://addons/dialogue_manager/import_plugin.gd")
const DialogueTranslationParserPlugin = preload("res://addons/dialogue_manager/editor_translation_parser_plugin.gd")
const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")
const DialogueCache = preload("res://addons/dialogue_manager/components/dialogue_cache.gd")
const MainView = preload("res://addons/dialogue_manager/views/main_view.tscn")


var import_plugin: DialogueImportPlugin
var translation_parser_plugin: DialogueTranslationParserPlugin
var main_view
var dialogue_cache: DialogueCache

var _recompile_timer: Timer = Timer.new()
var _recompile_paths: PackedStringArray


func _enter_tree() -> void:
	add_autoload_singleton("DialogueManager", "res://addons/dialogue_manager/dialogue_manager.gd")
	add_custom_type("DialogueLabel", "RichTextLabel", preload("res://addons/dialogue_manager/dialogue_label.gd"), _get_plugin_icon())

	if Engine.is_editor_hint():
		DialogueSettings.prepare()

		import_plugin = DialogueImportPlugin.new()
		import_plugin.editor_plugin = self
		add_import_plugin(import_plugin)

		translation_parser_plugin = DialogueTranslationParserPlugin.new()
		add_translation_parser_plugin(translation_parser_plugin)

		main_view = MainView.instantiate()
		main_view.editor_plugin = self
		get_editor_interface().get_editor_main_screen().add_child(main_view)
		_make_visible(false)

		main_view.add_child(_recompile_timer)
		_recompile_timer.timeout.connect(_on_recompile_timer_timeout)

		dialogue_cache = DialogueCache.new()
		_update_localization()

		get_editor_interface().get_file_system_dock().files_moved.connect(_on_files_moved)
		get_editor_interface().get_file_system_dock().file_removed.connect(_on_file_removed)

		add_tool_menu_item("Create copy of dialogue example balloon...", _copy_dialogue_balloon)


func _exit_tree() -> void:
	remove_autoload_singleton("DialogueManager")
	remove_custom_type("DialogueLabel")

	remove_import_plugin(import_plugin)
	import_plugin = null

	remove_translation_parser_plugin(translation_parser_plugin)
	translation_parser_plugin = null

	if is_instance_valid(main_view):
		main_view.queue_free()

	get_editor_interface().get_file_system_dock().files_moved.disconnect(_on_files_moved)
	get_editor_interface().get_file_system_dock().file_removed.disconnect(_on_file_removed)

	remove_tool_menu_item("Create copy of dialogue example balloon...")


func _has_main_screen() -> bool:
	return true


func _make_visible(next_visible: bool) -> void:
	if is_instance_valid(main_view):
		main_view.visible = next_visible


func _get_plugin_name() -> String:
	return "Dialogue"


func _get_plugin_icon() -> Texture2D:
	return load("res://addons/dialogue_manager/assets/icon.svg")


func _handles(object) -> bool:
	return object is DialogueResource


func _edit(object) -> void:
	if is_instance_valid(main_view) and is_instance_valid(object):
		main_view.open_resource(object)


func _apply_changes() -> void:
	if is_instance_valid(main_view):
		main_view.apply_changes()
		_update_localization()


func _build() -> bool:
	# Ignore errors in other files if we are just running the test scene
	if DialogueSettings.get_user_value("is_running_test_scene", true): return true

	var files_with_errors = dialogue_cache.get_files_with_errors()
	if files_with_errors.size() > 0:
		for dialogue_file in files_with_errors:
			push_error("You have %d error(s) in %s" % [dialogue_file.errors.size(), dialogue_file.path])
		get_editor_interface().edit_resource(load(files_with_errors[0].path))
		main_view.show_build_error_dialog()
		return false

	return true


## Keep track of known files and their dependencies
func add_file_to_cache(path: String, parse_results: DialogueManagerParseResult) -> void:
	dialogue_cache.add_file(path, parse_results)
	queue_recompile_of_dependencies(path)


## Keep track of compile errors
func add_errors_to_cache(path: String, errors: Array[Dictionary]) -> void:
	dialogue_cache.add_errors_to_file(path, errors)
	queue_recompile_of_dependencies(path)


## Update references to a moved file
func update_import_paths(from_path: String, to_path: String) -> void:
	dialogue_cache.move_file_path(from_path, to_path)

	# Reopen the file if it's already open
	if main_view.current_file_path == from_path:
		main_view.current_file_path = ""
		main_view.open_file(to_path)

	# Update any other files that import the moved file
	var dependents = dialogue_cache.get_files_with_dependency(from_path)
	for dependent in dependents:
		dependent.dependencies.erase(from_path)
		dependent.dependencies.append(to_path)

		# Update the live buffer
		if main_view.current_file_path == dependent.path:
			main_view.code_edit.text = main_view.code_edit.text.replace(from_path, to_path)
			main_view.pristine_text = main_view.code_edit.text

		# Open the file and update the path
		var file: FileAccess = FileAccess.open(dependent.path, FileAccess.READ)
		var text = file.get_as_text().replace(from_path, to_path)

		file = FileAccess.open(dependent.path, FileAccess.WRITE)
		file.store_string(text)


func queue_recompile_of_dependencies(of_path: String) -> void:
	_recompile_timer.stop()
	if not _recompile_paths.has(of_path):
		_recompile_paths.append(of_path)
	_recompile_timer.start(0.5)


func _update_localization() -> void:
	var dialogue_files = dialogue_cache.get_files()

	# Add any new files to POT generation
	var files_for_pot: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations_pot_files", [])
	var files_for_pot_changed: bool = false
	for path in dialogue_files:
		if not files_for_pot.has(path):
			files_for_pot.append(path)
			files_for_pot_changed = true

	# Remove any POT references that don't exist any more
	for i in range(files_for_pot.size() - 1, -1, -1):
		var file_for_pot: String = files_for_pot[i]
		if file_for_pot.get_extension() == "dialogue" and not dialogue_files.has(file_for_pot):
			files_for_pot.remove_at(i)
			files_for_pot_changed = true

	# Update project settings if POT changed
	if files_for_pot_changed:
		ProjectSettings.set_setting("internationalization/locale/translations_pot_files", files_for_pot)
		ProjectSettings.save()


### Callbacks


func _copy_dialogue_balloon() -> void:
	var scale: float = get_editor_interface().get_editor_scale()
	var directory_dialog: FileDialog = FileDialog.new()
	var label: Label = Label.new()
	label.text = "Dialogue balloon files will be copied into chosen directory."
	directory_dialog.get_vbox().add_child(label)
	directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	directory_dialog.min_size = Vector2(600, 500) * scale
	directory_dialog.dir_selected.connect(func(path):
		var file: FileAccess = FileAccess.open("res://addons/dialogue_manager/example_balloon/example_balloon.tscn", FileAccess.READ)
		var file_contents: String = file.get_as_text().replace("res://addons/dialogue_manager/example_balloon/example_balloon.gd", path + "/balloon.gd")
		file = FileAccess.open(path + "/balloon.tscn", FileAccess.WRITE)
		file.store_string(file_contents)
		file.close()

		file = FileAccess.open("res://addons/dialogue_manager/example_balloon/small_example_balloon.tscn", FileAccess.READ)
		file_contents = file.get_as_text().replace("res://addons/dialogue_manager/example_balloon/example_balloon.gd", path + "/balloon.gd")
		file = FileAccess.open(path + "/small_balloon.tscn", FileAccess.WRITE)
		file.store_string(file_contents)
		file.close()

		file = FileAccess.open("res://addons/dialogue_manager/example_balloon/example_balloon.gd", FileAccess.READ)
		file_contents = file.get_as_text()
		file = FileAccess.open(path + "/balloon.gd", FileAccess.WRITE)
		file.store_string(file_contents)
		file.close()

		get_editor_interface().get_resource_filesystem().scan()
		get_editor_interface().get_file_system_dock().call_deferred("navigate_to_path", path + "/balloon.tscn")

		directory_dialog.queue_free()
	)
	get_editor_interface().get_base_control().add_child(directory_dialog)
	directory_dialog.popup_centered()


### Signals


func _on_recompile_timer_timeout() -> void:
	_recompile_timer.stop()
	if _recompile_paths.size() > 0:
		var files_to_reimport: PackedStringArray = []
		for path in _recompile_paths:
			var dependencies = dialogue_cache.get_files_with_dependency(path).map(func(file): return file.path)
			for dependency in dependencies:
				if not files_to_reimport.has(dependency):
					files_to_reimport.append(dependency)

		if files_to_reimport.size() > 0:
			get_editor_interface().get_resource_filesystem().reimport_files(files_to_reimport)
			_recompile_paths = []


func _on_files_moved(old_file: String, new_file: String) -> void:
	update_import_paths(old_file, new_file)
	DialogueSettings.move_recent_file(old_file, new_file)


func _on_file_removed(file: String) -> void:
	queue_recompile_of_dependencies(file)
	if is_instance_valid(main_view):
		main_view.close_file(file)

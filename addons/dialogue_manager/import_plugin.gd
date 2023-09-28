@tool
extends EditorImportPlugin


signal compiled_resource(resource: Resource)


const DialogueResource = preload("./dialogue_resource.gd")
const compiler_version = 10


var editor_plugin


func _get_importer_name() -> String:
	# NOTE: A change to this forces a re-import of all dialogue
	return "dialogue_manager_compiler_%s" % compiler_version


func _get_visible_name() -> String:
	return "Dialogue"


func _get_import_order() -> int:
	return -1000


func _get_priority() -> float:
	return 1000.0


func _get_resource_type():
	return "Resource"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["dialogue"])


func _get_save_extension():
	return "tres"


func _get_preset_count() -> int:
	return 0


func _get_preset_name(preset_index: int) -> String:
	return "Unknown"


func _get_import_options(path: String, preset_index: int) -> Array:
	# When the options array is empty there is a misleading error on export
	# that actually means nothing so let's just have an invisible option.
	return [{
		name = "defaults",
		default_value = true
	}]


func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return false


func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	# Get the raw file contents
	if not FileAccess.file_exists(source_file): return ERR_FILE_NOT_FOUND

	var file: FileAccess = FileAccess.open(source_file, FileAccess.READ)
	var raw_text: String = file.get_as_text()

	# Parse the text
	var parser: DialogueManagerParser = DialogueManagerParser.new()
	var err: Error = parser.parse(raw_text, source_file)
	var data: DialogueManagerParseResult = parser.get_data()
	var errors: Array[Dictionary] = parser.get_errors()
	parser.free()

	if err != OK:
		printerr("%d errors found in %s" % [errors.size(), source_file])
		editor_plugin.add_errors_to_cache(source_file, errors)
		return err

	# Get the current addon version
	var config: ConfigFile = ConfigFile.new()
	config.load("res://addons/dialogue_manager/plugin.cfg")
	var version: String = config.get_value("plugin", "version")

	# Save the results to a resource
	var resource: DialogueResource = DialogueResource.new()
	resource.set_meta("dialogue_manager_version", version)

	resource.titles = data.titles
	resource.first_title = data.first_title
	resource.character_names = data.character_names
	resource.lines = data.lines

	# Clear errors and possibly trigger any cascade recompiles
	editor_plugin.add_file_to_cache(source_file, data)

	err = ResourceSaver.save(resource, "%s.%s" % [save_path, _get_save_extension()])

	compiled_resource.emit(resource)

	return err

@tool
class_name DMImportPlugin extends EditorImportPlugin


signal compiled_resource(resource: Resource)


const COMPILER_VERSION = 14


func _get_importer_name() -> String:
	# NOTE: A change to this forces a re-import of all dialogue
	return "dialogue_manager_compiler_%s" % COMPILER_VERSION


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
	var cache = Engine.get_meta("DMCache")

	# Get the raw file contents
	if not FileAccess.file_exists(source_file): return ERR_FILE_NOT_FOUND

	var file: FileAccess = FileAccess.open(source_file, FileAccess.READ)
	var raw_text: String = file.get_as_text()

	cache.file_content_changed.emit(source_file, raw_text)

	# Compile the text
	var result: DMCompilerResult = DMCompiler.compile_string(raw_text, source_file)
	if result.errors.size() > 0:
		printerr("%d errors found in %s" % [result.errors.size(), source_file])
		cache.add_errors_to_file(source_file, result.errors)
		return ERR_PARSE_ERROR

	# Get the current addon version
	var config: ConfigFile = ConfigFile.new()
	config.load("res://addons/dialogue_manager/plugin.cfg")
	var version: String = config.get_value("plugin", "version")

	# Save the results to a resource
	var resource: DialogueResource = DialogueResource.new()
	resource.set_meta("dialogue_manager_version", version)

	resource.using_states = result.using_states
	resource.titles = result.titles
	resource.first_title = result.first_title
	resource.character_names = result.character_names
	resource.lines = result.lines
	resource.raw_text = result.raw_text

	# Clear errors and possibly trigger any cascade recompiles
	cache.add_file(source_file, result)

	var err: Error = ResourceSaver.save(resource, "%s.%s" % [save_path, _get_save_extension()])

	compiled_resource.emit(resource)

	# Recompile any dependencies
	var dependent_paths: PackedStringArray = cache.get_dependent_paths_for_reimport(source_file)
	for path in dependent_paths:
		append_import_external_resource(path)

	return err

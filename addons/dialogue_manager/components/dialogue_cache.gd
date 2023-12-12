extends Node


const DialogueConstants = preload("../constants.gd")
const DialogueSettings = preload("../settings.gd")
const DialogueManagerParseResult = preload("./parse_result.gd")


# Keeps track of errors and dependencies.
# {
# 	<dialogue file path> = {
# 		path = <dialogue file path>,
# 		dependencies = [<dialogue file path>, <dialogue file path>],
# 		errors = [<error>, <error>]
# 	}
# }
var _cache: Dictionary = {}

var _update_dependency_timer: Timer = Timer.new()
var _update_dependency_paths: PackedStringArray = []


func _ready() -> void:
	add_child(_update_dependency_timer)
	_update_dependency_timer.timeout.connect(_on_update_dependency_timeout)

	_build_cache()


func reimport_files(files: PackedStringArray = []) -> void:
	if files.is_empty(): files = get_files()

	var file_system: EditorFileSystem = Engine.get_meta("DialogueManagerPlugin") \
		.get_editor_interface() \
		.get_resource_filesystem()

	# NOTE: Godot 4.2rc1 has an issue with reimporting more than one
	# file at a time so we do them one by one
	for file in files:
		file_system.reimport_files([file])
		await get_tree().create_timer(0.2)


## Add a dialogue file to the cache.
func add_file(path: String, parse_results: DialogueManagerParseResult = null) -> void:
	_cache[path] = {
		path = path,
		dependencies = [],
		errors = []
	}

	if parse_results != null:
		_cache[path].dependencies = Array(parse_results.imported_paths).filter(func(d): return d != path)
		_cache[path].parsed_at = Time.get_ticks_msec()

	# If this is a fresh cache entry then we need to check for dependencies
	if parse_results == null and not _update_dependency_paths.has(path):
		queue_updating_dependencies(path)


## Get the file paths in the cache.
func get_files() -> PackedStringArray:
	return _cache.keys()


## Remember any errors in a dialogue file.
func add_errors_to_file(path: String, errors: Array[Dictionary]) -> void:
	if _cache.has(path):
		_cache[path].errors = errors
	else:
		_cache[path] = {
			path = path,
			resource_path = "",
			dependencies = [],
			errors = errors
		}


## Get a list of files that have errors in them.
func get_files_with_errors() -> Array[Dictionary]:
	var files_with_errors: Array[Dictionary] = []
	for dialogue_file in _cache.values():
		if dialogue_file and dialogue_file.errors.size() > 0:
			files_with_errors.append(dialogue_file)
	return files_with_errors


## Queue a file to have it's dependencies checked
func queue_updating_dependencies(of_path: String) -> void:
	_update_dependency_timer.stop()
	if not _update_dependency_paths.has(of_path):
		_update_dependency_paths.append(of_path)
	_update_dependency_timer.start(0.5)


## Update any references to a file path that has moved
func move_file_path(from_path: String, to_path: String) -> void:
	if not _cache.has(from_path): return

	if to_path != "":
		_cache[to_path] = _cache[from_path].duplicate()
	_cache.erase(from_path)


## Get any dialogue files that import a given path.
func get_files_with_dependency(imported_path: String) -> Array:
	return _cache.values().filter(func(d): return d.dependencies.has(imported_path))


## Get any paths that are dependent on a given path
func get_dependent_paths_for_reimport(on_path: String) -> PackedStringArray:
	return get_files_with_dependency(on_path) \
		.filter(func(d): return Time.get_ticks_msec() - d.get("parsed_at", 0) > 3000) \
		.map(func(d): return d.path)


# Build the initial cache for dialogue files.
func _build_cache() -> void:
	var current_files: PackedStringArray = _get_dialogue_files_in_filesystem()
	for file in current_files:
		add_file(file)


# Recursively find any dialogue files in a directory
func _get_dialogue_files_in_filesystem(path: String = "res://") -> PackedStringArray:
	var files: PackedStringArray = []

	if DirAccess.dir_exists_absolute(path):
		var dir = DirAccess.open(path)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var file_path: String = (path + "/" + file_name).simplify_path()
			if dir.current_is_dir():
				if not file_name in [".godot", ".tmp"]:
					files.append_array(_get_dialogue_files_in_filesystem(file_path))
			elif file_name.get_extension() == "dialogue":
				files.append(file_path)
			file_name = dir.get_next()

	return files


### Signals


func _on_update_dependency_timeout() -> void:
	_update_dependency_timer.stop()
	var import_regex: RegEx = RegEx.create_from_string("import \"(?<path>.*?)\"")
	var file: FileAccess
	var found_imports: Array[RegExMatch]
	for path in _update_dependency_paths:
		# Open the file and check for any "import" lines
		file = FileAccess.open(path, FileAccess.READ)
		found_imports = import_regex.search_all(file.get_as_text())
		var dependencies: PackedStringArray = []
		for found in found_imports:
			dependencies.append(found.strings[found.names.path])
		_cache[path].dependencies = dependencies
	_update_dependency_paths.clear()

extends Node


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")
const DialogueSettings = preload("res://addons/dialogue_manager/components/settings.gd")


# Keeps track of errors and dependencies.
# {
# 	<dialogue file path> = {
# 		path = <dialogue file path>,
# 		dependencies = [<dialogue file path>, <dialogue file path>],
# 		errors = [<error>, <error>]
# 	}
# }
var _cache: Dictionary = {}


func _init() -> void:
	_build_cache()


## Add a dialogue file to the cache.
func add_file(path: String, parse_results: DialogueManagerParseResult = null) -> void:
	var dependencies: PackedStringArray = []

	if parse_results != null:
		dependencies = Array(parse_results.imported_paths).filter(func(d): return d != path)

	_cache[path] = {
		path = path,
		dependencies = dependencies,
		errors = []
	}

	# If this is a fresh cache entry then we need to check for dependencies
	if parse_results == null:
		WorkerThreadPool.add_task(_update_dependencies.bind(path))


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


## Update any references to a file path that has moved
func move_file_path(from_path: String, to_path: String) -> void:
	if _cache.has(from_path):
		_cache[to_path] = _cache[from_path].duplicate()
		_cache.erase(from_path)


## Get any dialogue files that import a given path.
func get_files_with_dependency(imported_path: String) -> Array:
	return _cache.values().filter(func(d): return imported_path in d.dependencies)


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


# Check for dependencies of a path
func _update_dependencies(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var import_regex: RegEx = RegEx.create_from_string("import \"(?<path>.*?)\"")
	var found_imports = import_regex.search_all(file.get_as_text())
	var dependencies: PackedStringArray = []
	for found in found_imports:
		dependencies.append(found.strings[found.names.path])
	_cache[path].dependencies = dependencies

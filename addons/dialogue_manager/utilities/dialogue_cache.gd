class_name DMCache extends RefCounted


## Keep track of errors and dependencies
## {
## 	<dialogue file path> = {
## 		path = <dialogue file path>,
## 		dependencies = [<dialogue file path>, <dialogue file path>],
## 		errors = [<error>, <error>]
## 	}
## }
static var _cache: Dictionary = {}

static var _update_dependency_timer: Timer
static var _update_dependency_paths: PackedStringArray = []

static var _files_marked_for_reimport: PackedStringArray = []
static var _is_reimport_scheduled: bool = false

## Keep track of used static IDs
## {
## 	<static ID> = <file path>
## }
## Before compiling a file, remove any static IDs with a file path that matches
## the file
static var known_static_ids: Dictionary = {}


## Build the initial cache for dialogue files
static func prepare() -> void:
	_update_dependency_timer = Timer.new()
	_update_dependency_timer.timeout.connect(_on_dependency_timer_timeout)
	(Engine.get_main_loop() as SceneTree).root.add_child(_update_dependency_timer)

	var current_files: PackedStringArray = _get_dialogue_files_in_filesystem()
	for file: String in current_files:
		add_file(file)

	# Find any static IDs
	var key_regex: RegEx = RegEx.create_from_string("\\[ID:(?<key>.*?)\\]")
	for file_path: String in get_files():
		var text: String = FileAccess.get_file_as_string(file_path)
		var lines: PackedStringArray = text.split("\n")
		for i: int in range(0, lines.size()):
			var line: String = lines[i]
			var found: RegExMatch = key_regex.search(line)
			if found:
				known_static_ids[found.strings[found.names.get("key")]] = file_path


## Add some files to the queue for reimporting.
static func mark_files_for_reimport(files: PackedStringArray) -> void:
	for file: String in files:
		if not _files_marked_for_reimport.has(file):
			_files_marked_for_reimport.append(file)


## Attempt to reimport all known dialogue files.
static func reimport_all_files() -> void:
	reimport_files(_get_dialogue_files_in_filesystem())


## Attempt to reimport any files marked for reimporting.
static func reimport_files(and_files: PackedStringArray = []) -> void:
	mark_files_for_reimport(and_files)

	if _files_marked_for_reimport.is_empty(): return

	# Something is already waiting for the file system, so it will pick these files up too.
	if _is_reimport_scheduled: return

	if _is_file_system_busy():
		_reimport_when_file_system_is_free()
		return

	_reimport_marked_files()


# Wait for the file system to finish whatever it is doing and then reimport.
static func _reimport_when_file_system_is_free() -> void:
	_is_reimport_scheduled = true
	while _is_file_system_busy():
		await Engine.get_main_loop().create_timer(0.1).timeout
	_is_reimport_scheduled = false

	_reimport_marked_files()


# Hand any marked files over to the editor's import system.
static func _reimport_marked_files() -> void:
	if _files_marked_for_reimport.is_empty(): return

	# Importing can mark more files for reimport (eg. dependencies) so take the files we know about
	# now and clear the queue before importing them.
	var files: PackedStringArray = _files_marked_for_reimport.duplicate()
	_files_marked_for_reimport.clear()

	Engine.get_singleton("EditorInterface").get_resource_filesystem().reimport_files(files)


# Check if the file system is mid-scan or mid-import.
static func _is_file_system_busy() -> bool:
	var file_system: Object = Engine.get_singleton("EditorInterface").get_resource_filesystem()
	return file_system.is_scanning() or file_system.is_importing()


## Add a dialogue file to the cache.
static func add_file(path: String, compile_result: DMCompilerResult = null) -> void:
	_cache[path] = {
		path = path,
		cues = {},
		dependencies = [],
		errors = []
	}

	if compile_result != null:
		_cache[path].cues = compile_result.cues
		_cache[path].dependencies = Array(compile_result.imported_paths).filter(func(d: String) -> bool: return d != path)
		_cache[path].compiled_at = Time.get_ticks_msec()

	queue_updating_dependencies(path)


## Get the file paths in the cache.
static func get_files() -> PackedStringArray:
	return _cache.keys()


## Get the data for a file path.
static func get_file_data(key: String) -> Dictionary:
	return _cache.get(key, {})


## Check if a file is known to the cache.
static func has_file(path: String) -> bool:
	return _cache.has(path)


## Remember any errors in a dialogue file.
static func add_errors_to_file(path: String, errors: Array[DMError]) -> void:
	if _cache.has(path):
		_cache[path].errors = errors
	else:
		_cache[path] = {
			path = path,
			resource_path = "",
			dependencies = [],
			errors = errors
		}


## Get a list of files that have errors.
static func get_files_with_errors() -> Array[Dictionary]:
	var files_with_errors: Array[Dictionary] = []
	for dialogue_file: Dictionary in _cache.values():
		if dialogue_file and dialogue_file.errors.size() > 0:
			files_with_errors.append(dialogue_file)
	return files_with_errors


## Queue a file to have its dependencies checked.
static func queue_updating_dependencies(of_path: String) -> void:
	if _update_dependency_paths.has(of_path): return
	if is_instance_valid(_update_dependency_timer):
		_update_dependency_timer.stop()

	if not _update_dependency_paths.has(of_path):
		_update_dependency_paths.append(of_path)

	if is_instance_valid(_update_dependency_timer):
		_update_dependency_timer.start(0.5)


## Update any references to a file path that has moved.
static func move_file_path(from_path: String, to_path: String) -> void:
	if not _cache.has(from_path): return

	if to_path != "":
		_cache[to_path] = _cache[from_path].duplicate()
	_cache.erase(from_path)


## Get every dialogue file that imports on a file of a given path.
static func get_files_with_dependency(imported_path: String) -> Array:
	return _cache.values().filter(func(d: Dictionary) -> bool: return d.dependencies.has(imported_path))


## Get any paths that are dependent on a given path.
static func get_dependent_paths_for_reimport(on_path: String) -> PackedStringArray:
	return get_files_with_dependency(on_path) \
		.filter(func(d: Dictionary) -> bool: return Time.get_ticks_msec() - d.get("compiled_at", 0) > 3000) \
		.map(func(d: Dictionary) -> String: return d.path)


# Recursively find any dialogue files in a directory.
static func _get_dialogue_files_in_filesystem(path: String = "res://") -> PackedStringArray:
	var files: PackedStringArray = []

	if DirAccess.dir_exists_absolute(path):
		var dir: DirAccess = DirAccess.open(path)
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			var file_path: String = (path + "/" + file_name).simplify_path()
			if dir.current_is_dir():
				if not file_name in [".godot", ".tmp"]:
					files.append_array(_get_dialogue_files_in_filesystem(file_path))
			elif file_name.get_extension() == "dialogue":
				files.append(file_path)
			file_name = dir.get_next()

	return files


#region Signals


static func _on_dependency_timer_timeout() -> void:
	if is_instance_valid(_update_dependency_timer):
		_update_dependency_timer.stop()

	var import_regex: RegEx = RegEx.create_from_string("import \"(?<path>.*?)\"")
	var file: FileAccess
	var found_imports: Array[RegExMatch]
	for path: String in _update_dependency_paths:
		# Open the file and check for any "import" lines
		file = FileAccess.open(path, FileAccess.READ)
		found_imports = import_regex.search_all(file.get_as_text())
		var dependencies: PackedStringArray = []
		for found: RegExMatch in found_imports:
			dependencies.append(found.strings[found.names.path])
		_cache[path].dependencies = dependencies
	_update_dependency_paths.clear()


#endregion

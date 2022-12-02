@tool
extends Control


signal failed()
signal updated(updated_to_version: String)


const TEMP_FILE_NAME = "user://temp.zip"


@onready var logo: TextureRect = %Logo
@onready var label: Label = $VBox/Label
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var download_button: Button = %DownloadButton

var next_version: String = "":
	set(next_next_version):
		next_version = next_next_version
		label.text = "Version %s is available for download!" % next_version
	get:
		return next_version
	

func save_zip(bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(TEMP_FILE_NAME, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.flush()


### Signals


func _on_download_button_pressed() -> void:
	# Safeguard the actual dialogue manager repo from accidentally updating itself
	if FileAccess.file_exists("res://examples/test_scenes/test_scene.gd"): 
		prints("You can't update the dialogue manager from within itself.")
		emit_signal("failed")
		return
	
	http_request.request("https://github.com/nathanhoad/godot_dialogue_manager/archive/refs/tags/v%s.zip" % next_version)
	download_button.disabled = true
	download_button.text = "Downloading..."


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS: 
		emit_signal("failed")
		return
	
	# Save the downloaded zip
	save_zip(body)
	
	if DirAccess.dir_exists_absolute("res://addons/dialogue_manager"):
		DirAccess.remove_absolute("res://addons/dialogue_manager")
	
	var zip_reader: ZIPReader = ZIPReader.new()
	zip_reader.open(TEMP_FILE_NAME)
	var files: PackedStringArray = zip_reader.get_files()
	
	var base_path = files[1]
	# Remove archive folder
	files.remove_at(0)
	# Remove assets folder
	files.remove_at(0)
	
	for path in files:
		var new_file_path: String = path.replace(base_path, "")
		if path.ends_with("/"):
			DirAccess.make_dir_recursive_absolute("res://addons/%s" % new_file_path)
		else:
			var file: FileAccess = FileAccess.open("res://addons/%s" % new_file_path, FileAccess.WRITE)
			file.store_buffer(zip_reader.read_file(path))
		
	zip_reader.close()
	
	DirAccess.remove_absolute(TEMP_FILE_NAME)
	
	emit_signal("updated", next_version)


func _on_notes_button_pressed() -> void:
	OS.shell_open("https://github.com/nathanhoad/godot_dialogue_manager/releases/tag/v%s" % next_version)

@tool
extends Control


signal failed()
signal updated(updated_to_version: String)


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")

const TEMP_FILE_NAME = "user://temp.zip"


@onready var logo: TextureRect = %Logo
@onready var label: Label = $VBox/Label
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var download_button: Button = %DownloadButton

var next_version_release: Dictionary:
	set(value):
		next_version_release = value
		label.text = DialogueConstants.translate("update.is_available_for_download") % value.tag_name.substr(1)
	get:
		return next_version_release


func _ready() -> void:
	$VBox/Center/DownloadButton.text = DialogueConstants.translate("update.download_update")
	$VBox/Center2/NotesButton.text = DialogueConstants.translate("update.release_notes")


### Signals


func _on_download_button_pressed() -> void:
	# Safeguard the actual dialogue manager repo from accidentally updating itself
	if FileAccess.file_exists("res://examples/test_scenes/test_scene.gd"):
		prints("You can't update the addon from within itself.")
		failed.emit()
		return

	http_request.request(next_version_release.zipball_url)
	download_button.disabled = true
	download_button.text = DialogueConstants.translate("update.downloading")


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit()
		return

	# Save the downloaded zip
	var zip_file: FileAccess = FileAccess.open(TEMP_FILE_NAME, FileAccess.WRITE)
	zip_file.store_buffer(body)
	zip_file.close()

	OS.move_to_trash(ProjectSettings.globalize_path("res://addons/dialogue_manager"))

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

	updated.emit(next_version_release.tag_name.substr(1))


func _on_notes_button_pressed() -> void:
	OS.shell_open(next_version_release.html_url)

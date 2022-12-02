@tool
extends Button


const REMOTE_CONFIG_URL = "https://raw.githubusercontent.com/nathanhoad/godot_dialogue_manager/main/addons/dialogue_manager/plugin.cfg"
const LOCAL_CONFIG_PATH = "res://addons/dialogue_manager/plugin.cfg"


@onready var http_request: HTTPRequest = $HTTPRequest
@onready var download_dialog: AcceptDialog = $DownloadDialog
@onready var download_update_panel = $DownloadDialog/DownloadUpdatePanel
@onready var update_failed_dialog: AcceptDialog = $UpdateFailedDialog

# The main editor plugin
var editor_plugin: EditorPlugin

# A lambda that gets called just before refreshing the plugin. Return false to stop the reload.
var on_before_refresh: Callable = func(): return true


func _ready() -> void:
	hide()
	apply_theme()
	
	# Check for updates on GitHub
	http_request.request(REMOTE_CONFIG_URL)


# Get the current version
func get_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	config.load(LOCAL_CONFIG_PATH)
	return config.get_value("plugin", "version")


# Convert a version number to an actually comparable number
func version_to_number(version: String) -> int:
	var bits = version.split(".")
	return bits[0].to_int() * 1000000 + bits[1].to_int() * 1000 + bits[2].to_int()


func apply_theme() -> void:
	add_theme_color_override("font_color", get_theme_color("success_color", "Editor"))
	add_theme_color_override("font_hover_color", get_theme_color("success_color", "Editor"))


### Signals


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS: return
	
	# Parse the version number from the remote config file
	var response = body.get_string_from_utf8()
	var regex = RegEx.new()
	regex.compile("version=\"(?<version>\\d+\\.\\d+\\.\\d+)\"")
	var found = regex.search(response)
	
	if not found: return
	
	var current_version: String = get_version()
	var next_version = found.strings[found.names.get("version")]
	if version_to_number(next_version) > version_to_number(current_version):
		download_update_panel.next_version = next_version
		text = "v%s available" % next_version
		show()


func _on_update_button_pressed() -> void:
	var scale: float = editor_plugin.get_editor_interface().get_editor_scale()
	download_dialog.min_size = Vector2(300, 250) * scale
	download_dialog.popup_centered()


func _on_download_dialog_close_requested() -> void:
	download_dialog.hide()


func _on_download_update_panel_updated(updated_to_version: String) -> void:
	download_dialog.hide()
	
	editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	
	var will_refresh = on_before_refresh.call()
	if will_refresh:
		print_rich("\n[b]Updated Dialogue Manager to v%s[/b]\n" % updated_to_version)
		editor_plugin.get_editor_interface().call_deferred("set_plugin_enabled", "dialogue_manager", true)
		editor_plugin.get_editor_interface().set_plugin_enabled("dialogue_manager", false)


func _on_download_update_panel_failed() -> void:
	download_dialog.hide()
	update_failed_dialog.dialog_text = "There was a problem downloading the update."
	update_failed_dialog.popup_centered()

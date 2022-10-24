@tool
extends Button


const OPEN_URL = "https://github.com/nathanhoad/godot_dialogue_manager"
const REMOTE_CONFIG_URL = "https://raw.githubusercontent.com/nathanhoad/godot_dialogue_manager/main/addons/dialogue_manager/plugin.cfg"
const LOCAL_CONFIG_PATH = "res://addons/dialogue_manager/plugin.cfg"


@onready var http_request: HTTPRequest = $HTTPRequest
@onready var version_on_load: String = get_version()

# The main editor plugin
var editor_plugin: EditorPlugin

# A lambda that gets called just before refreshing the plugin. Return false to stop the reload.
var on_before_refresh: Callable = func(): return true


func _ready() -> void:
	hide()
	apply_theme()
	check_for_remote_update()
	

# Check for updates on GitHub
func check_for_remote_update() -> void:
	http_request.request(REMOTE_CONFIG_URL)


# Check for local file updates and restart the plugin if found
func check_for_local_update() -> void:
	var next_version = get_version()
	if version_to_number(next_version) > version_to_number(version_on_load):
		var will_refresh = on_before_refresh.call()
		if will_refresh:
			if editor_plugin.get_editor_interface().get_resource_filesystem().sources_changed.is_connected(_on_sources_changed):
				editor_plugin.get_editor_interface().get_resource_filesystem().sources_changed.disconnect(_on_sources_changed)
			print_rich("\n[b]Updated Dialogue Manager to v%s[/b]\n" % next_version)
			editor_plugin.get_editor_interface().call_deferred("set_plugin_enabled", "dialogue_manager", true)
			editor_plugin.get_editor_interface().set_plugin_enabled("dialogue_manager", false)


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
	
	var next_version = found.strings[found.names.get("version")]
	if version_to_number(next_version) > version_to_number(version_on_load):
		text = "v%s available" % next_version
		show()
		# Wait for the local files to be updated
		editor_plugin.get_editor_interface().get_resource_filesystem().sources_changed.connect(_on_sources_changed)


func _on_update_button_pressed() -> void:
	OS.shell_open(OPEN_URL)


func _on_sources_changed(exist: bool) -> void:
	check_for_local_update()

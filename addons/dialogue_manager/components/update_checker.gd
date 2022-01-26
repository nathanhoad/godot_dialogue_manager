tool
extends HTTPRequest


signal has_update(version, url)


export var plugin_url: String = ""
export var plugin_config_url: String = ""


func check_for_updates() -> void:
	if plugin_config_url != "":
		request(plugin_config_url)


func version_to_number(version: String) -> int:
	var bits = version.split(".")
	return int(bits[0]) * 1000000 + int(bits[1]) * 1000 + int(bits[2])


### Signals


func _on_UpdateChecker_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS: return
	
	var text = body.get_string_from_utf8()
	var regex = RegEx.new()
	regex.compile("version=\"(?<version>\\d+\\.\\d+\\.\\d+)\"")
	var found = regex.search(text)
	
	if not found: return
		
	var plugin_config = ConfigFile.new()
	var config = ConfigFile.new()
	var success = config.load("res://addons/dialogue_manager/plugin.cfg")
	
	if success != OK: return
	
	var current_version = config.get_value("plugin", "version")
	var next_version = found.strings[found.names.get("version")]
	if version_to_number(next_version) > version_to_number(current_version):
		emit_signal("has_update", next_version, plugin_url)

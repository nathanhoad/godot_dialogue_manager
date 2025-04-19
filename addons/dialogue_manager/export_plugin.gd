class_name DMExportPlugin extends EditorExportPlugin

const IGNORED_PATHS = [
	"/assets",
	"/components",
	"/views",
	"inspector_plugin",
	"test_scene"
]


func _get_name() -> String:
	return "Dialogue Manager Export Plugin"


func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	var plugin_path: String = Engine.get_meta("DialogueManagerPlugin").get_plugin_path()

	# Ignore any editor stuff
	for ignored_path: String in IGNORED_PATHS:
		if path.begins_with(plugin_path + ignored_path):
			skip()

	# Ignore C# stuff it not using dotnet
	if path.begins_with(plugin_path) and not DMSettings.check_for_dotnet_solution() and path.ends_with(".cs"):
		skip()

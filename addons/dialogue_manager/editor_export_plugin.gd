extends EditorExportPlugin


const Constants = preload("res://addons/dialogue_manager/constants.gd")


func _export_begin(_features, _is_debug, _path, _flags):
	# Add our config file to the build
	var file = File.new()
	if file.file_exists(Constants.CONFIG_PATH):
		file.open(Constants.CONFIG_PATH, File.READ)
		var contents = file.get_buffer(file.get_len())
		file.close()
		add_file(Constants.CONFIG_PATH, contents, false)

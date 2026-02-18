class_name DMDialogueProcessor extends RefCounted


## Override to modify the incoming raw string.
func _preprocess_line(raw_line: String) -> String:
	return raw_line


## Override to modify the outgoing dialogue line.
func _process_line(_line: DMCompiledLine) -> void:
	pass

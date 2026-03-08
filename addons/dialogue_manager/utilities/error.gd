class_name DMError extends RefCounted

var line_number: int
var column_number: int
var error: int


func _init(data: Dictionary) -> void:
	line_number = data.get("line_number", 0)
	column_number = data.get("column_number", 0)
	error = data.get("error", DMConstants.ERR_UNKNOWN_ERROR)

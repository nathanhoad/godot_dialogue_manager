extends RefCounted


var tags: PackedStringArray = []
var line_without_tags: String = ""


func _init(data: Dictionary) -> void:
	tags = data.tags
	line_without_tags = data.line_without_tags

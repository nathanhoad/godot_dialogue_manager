extends RichTextLabel


var is_allowed: bool = true setget set_is_allowed


func set_is_allowed(value: bool) -> void:
	is_allowed = value
	modulate.a = 1 if is_allowed else 0.3

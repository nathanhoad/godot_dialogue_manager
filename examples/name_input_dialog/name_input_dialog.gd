extends AcceptDialog


@onready var name_edit: LineEdit = $NameEdit


func _ready() -> void:
	register_text_enter(name_edit)


### Signals


func _on_name_input_dialog_about_to_popup() -> void:
	name_edit.text = "Player"
	name_edit.call_deferred("grab_focus")
	name_edit.call_deferred("select_all")


func _on_name_input_dialog_close_requested() -> void:
	emit_signal("confirmed")

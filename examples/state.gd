extends Node


var player_name: String = ""


func ask_for_name() -> void:
	var name_input_dialog = load("res://examples/name_input_dialog/name_input_dialog.tscn").instantiate()
	get_tree().root.add_child(name_input_dialog)
	name_input_dialog.popup_centered()
	await name_input_dialog.confirmed
	player_name = name_input_dialog.name_edit.text
	name_input_dialog.queue_free()


var has_met_nathan: bool = false

class_name DMWaiter extends Node


signal waited()


var _actions: PackedStringArray
var _null: String = str(null)


func _init(target_actions: PackedStringArray) -> void:
	_actions = target_actions


func _input(event: InputEvent) -> void:
	for action: String in _actions:
		if event.is_pressed():
			if action == _null or (InputMap.has_action(action) and event.is_action(action)):
				get_viewport().set_input_as_handled()
				waited.emit()

class_name DMWaiter extends Node


signal waited()


var _actions: PackedStringArray


func _init(target_actions: PackedStringArray) -> void:
	_actions = target_actions


func _input(event: InputEvent) -> void:
	for action: String in _actions:
		if event.is_pressed():
			if action == "any" or event.is_action(action):
				waited.emit()

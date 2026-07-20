class_name DMWaiter extends Node


signal waited(for_action: String)


static var all_waiters: Array[DMWaiter]

var _actions: PackedStringArray
var _null: String = str(null)


## Emit [code]waited[/code] on all waiting [DMWaiter]s.
static func clear_all() -> void:
	for waiter: DMWaiter in all_waiters:
		all_waiters.erase(waiter)
		waiter.waited.emit(null)


func _init(target_actions: PackedStringArray) -> void:
	all_waiters.append(self)
	_actions = target_actions


func _exit_tree() -> void:
	all_waiters.erase(self)


func _input(event: InputEvent) -> void:
	for action: String in _actions:
		if event.is_pressed():
			if action == _null or (InputMap.has_action(action) and event.is_action(action)):
				get_viewport().set_input_as_handled()
				all_waiters.erase(self)
				waited.emit(action)

extends Node


var some_property: int = 0
var character_name: String = "Coco"

var dictionary: Dictionary = {}

var jump_target: String = "start"

var something_null: Variant = null

var thing: SomeClass = SomeClass.new()

var _counters: Dictionary = {}


func is_something(something: Variant, type: Variant) -> bool:
	return is_instance_of(something, type)


func noop() -> void:
	pass


func some_method(number: int, string: String) -> int:
	return number * string.length()


func long_mutation() -> void:
	await get_tree().create_timer(0.5).timeout


func typed_array_method(numbers: Array[int], strings: Array[String], dictionaries: Array) -> String:
	return str(numbers) + str(strings) + str(dictionaries)


func seen(key: String) -> bool:
	return _counters.get(key, 0) == 0


func see(key: String) -> void:
	_counters[key] = _counters.get(key, 0) + 1


static func some_static_function() -> bool:
	return true

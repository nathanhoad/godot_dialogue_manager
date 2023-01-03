class_name DialogueResponse extends RefCounted


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


var type: String = DialogueConstants.TYPE_RESPONSE
var next_id: String = ""
var is_allowed: bool = true
var text: String = ""
var text_replacements: Array[Dictionary] = []
var translation_key: String = ""


func _init(data: Dictionary = {}) -> void:
	if data.size() > 0:
		type = data.type
		next_id = data.next_id
		is_allowed = data.is_allowed
		text = data.text
		text_replacements = data.text_replacements
		translation_key = data.translation_key

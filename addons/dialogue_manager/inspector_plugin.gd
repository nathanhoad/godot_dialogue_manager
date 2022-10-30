@tool
extends EditorInspectorPlugin


const DialogueEditorProperty = preload("res://addons/dialogue_manager/components/editor_property/editor_property.gd")


var editor_plugin: EditorPlugin


func _can_handle(object) -> bool:
	return "dialogue_resource" in object


func _parse_property(object: Object, type: int, name: String, hint_type: int, hint_string: String, usage_flags: int, wide: bool) -> bool:
	match name:
		"dialogue_resource":
			var property_editor = DialogueEditorProperty.new(editor_plugin)
			add_property_editor(name, property_editor)
			return true
	
	return false

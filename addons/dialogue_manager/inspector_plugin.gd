@tool
class_name DMInspectorPlugin extends EditorInspectorPlugin


const DialogueEditorProperty = preload("./components/editor_property/editor_property.gd")


func _can_handle(object) -> bool:
	if object is GDScript: return false
	if not object is Node and not object is Resource: return false
	if "name" in object and object.name == "Dialogue Manager": return false
	return true


func _parse_property(object: Object, type, name: String, hint_type, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if hint_string == "DialogueResource" or ("dialogue" in name.to_lower() and hint_string == "Resource"):
		var property_editor = DialogueEditorProperty.new()
		add_property_editor(name, property_editor)
		return true

	return false

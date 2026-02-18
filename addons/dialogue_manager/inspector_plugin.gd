@tool
class_name DMInspectorPlugin extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	if object is GDScript: return false
	if not object is Node and not object is Resource: return false
	if "name" in object and object.name == "Dialogue Manager": return false
	return true


func _parse_property(_object: Object, _type: Variant, name: String, _hint_type: PropertyHint, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if hint_string == "DialogueResource" or ("dialogue" in name.to_lower() and hint_string == "Resource"):
		add_property_editor(name, DMDialogueEditorProperty.new())
		return true

	return false

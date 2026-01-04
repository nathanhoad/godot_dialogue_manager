@tool

class_name DMDialogueEditorProperty extends EditorProperty


const DialoguePropertyEditorControl: PackedScene = preload("./editor_property_control.tscn")


var control = DialoguePropertyEditorControl.instantiate()
var current_value: DialogueResource
var is_updating: bool = false


func _init() -> void:
	add_child(control)

	control.resource = current_value

	control.resource_changed.connect(_on_resource_changed)


func _update_property() -> void:
	var next_value: DialogueResource = get_edited_object()[get_edited_property()]

	# The resource might have been deleted elsewhere so check that it's not in a weird state
	if is_instance_valid(next_value) and not next_value.resource_path.ends_with(".dialogue"):
		emit_changed(get_edited_property(), null)
		return

	if next_value == current_value: return

	is_updating = true
	current_value = next_value
	control.resource = current_value
	is_updating = false


#region Signals


func _on_resource_changed(next_resource: DialogueResource) -> void:
	emit_changed(get_edited_property(), next_resource)


#endregion

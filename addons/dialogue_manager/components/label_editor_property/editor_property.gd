@tool
class_name DMLabelEditorProperty extends EditorProperty


var DialogueLabelPropertyEditorControl: PackedScene = preload("./editor_property_control.tscn")
var control: Control = DialogueLabelPropertyEditorControl.instantiate()
var current_value: String
var is_updating: bool = false


func _init() -> void:
	add_child(control)

	control.label = current_value

	control.label_changed.connect(_on_label_changed)


func _update_property() -> void:
	control.actionable = get_edited_object()

	var next_value: String = get_edited_object()[get_edited_property()]

	if next_value.is_empty():
		control.label = ""
		return

	if next_value == current_value: return

	is_updating = true
	current_value = next_value
	control.label = current_value
	is_updating = false


#region Signals


func _on_label_changed(next_label: String) -> void:
	emit_changed(get_edited_property(), next_label)


#endregion

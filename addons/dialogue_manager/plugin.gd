tool
extends EditorPlugin


const DialogueResource = preload("res://addons/dialogue_manager/dialogue_resource.gd")
const DialogueExportPlugin = preload("res://addons/dialogue_manager/editor_export_plugin.gd")

const MainView = preload("res://addons/dialogue_manager/views/main_view.tscn")


var export_plugin = DialogueExportPlugin.new()
var main_view


func _enter_tree() -> void:
	add_autoload_singleton("DialogueManager", "res://addons/dialogue_manager/dialogue_manager.gd")
	add_custom_type("DialogueLabel", "RichTextLabel", preload("res://addons/dialogue_manager/dialogue_label.gd"), get_plugin_icon())
	
	if Engine.editor_hint:
		add_export_plugin(export_plugin)
		
		main_view = MainView.instance()
		get_editor_interface().get_editor_viewport().add_child(main_view)
		main_view.plugin = self
		make_visible(false)


func _exit_tree() -> void:
	remove_custom_type("DialogueLabel")
	remove_autoload_singleton("DialogueManager")
	
	if is_instance_valid(main_view):
		main_view.queue_free()
	
	if export_plugin:
		remove_export_plugin(export_plugin)


func has_main_screen() -> bool:
	return true


func make_visible(next_visible: bool) -> void:
	if is_instance_valid(main_view):
		main_view.visible = next_visible


func get_plugin_name() -> String:
	return "Dialogue"


func get_plugin_icon() -> Texture:
	var base_color = get_editor_interface().get_editor_settings().get_setting("interface/theme/base_color")
	var theme = "light" if base_color.v > 0.5 else "dark"
	var base_icon = load("res://addons/dialogue_manager/assets/icons/icon_%s.svg" % [theme]) as Texture
	
	var size = get_editor_interface().get_editor_viewport().get_icon("Godot", "EditorIcons").get_size()
	var image: Image = base_icon.get_data()
	image.resize(size.x, size.y, Image.INTERPOLATE_TRILINEAR)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture


func handles(object) -> bool:
	return object is DialogueResource


func edit(object) -> void:
	if is_instance_valid(main_view):
		main_view.open_resource(object)
	

func apply_changes() -> void:
	if is_instance_valid(main_view):
		main_view.apply_changes()

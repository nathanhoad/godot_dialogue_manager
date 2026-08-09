@tool

extends CenterContainer


signal new_button_pressed
signal quick_open_button_pressed


@onready var banner_image: TextureRect = %BannerImage
@onready var new_button: Button = %NewButton
@onready var quick_open: Button = %QuickOpen
@onready var examples: Button = %Examples
@onready var buy_my_game: Button = %BuyMyGame


func apply_theme() -> void:
	var theme_values: DMThemeValues = DMThemeValues.get_values_from_editor()
	banner_image.custom_minimum_size = Vector2(300, 200) * theme_values.scale

	new_button.icon = get_theme_icon("New", "EditorIcons")
	new_button.text = DMConstants.translate(&"start_a_new_file")
	quick_open.icon = get_theme_icon("Load", "EditorIcons")
	quick_open.text = DMConstants.translate(&"open.quick_open")

	examples.icon = get_theme_icon("EditorFileDialog", "EditorIcons")
	examples.text = DMConstants.translate("Get example projects...")
	buy_my_game.icon = get_theme_icon("CharacterBody2D", "EditorIcons")
	buy_my_game.text = DMConstants.translate("Buy my game...")


#region Signals


func _on_banner_image_gui_input(event: InputEvent) -> void:
	if event.is_pressed():
		OS.shell_open("https://github.com/nathanhoad/godot_dialogue_manager")


func _on_new_button_pressed() -> void:
	new_button_pressed.emit()


func _on_quick_open_pressed() -> void:
	quick_open_button_pressed.emit()


func _on_examples_pressed() -> void:
	OS.shell_open("https://itch.io/c/5226650/godot-dialogue-manager-example-projects")


func _on_buy_my_game_pressed() -> void:
	OS.shell_open("https://bravestcoconut.com/wishlist")


#endregion

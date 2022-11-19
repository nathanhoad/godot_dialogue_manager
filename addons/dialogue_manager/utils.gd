extends Node


## Generate the plugin icon
static func create_main_icon(size: Vector2) -> Texture2D:
	var control: Control = Control.new()
	var base_color: Color = control.get_theme_color("base_color", "Editor")
	var theme: String = "light" if base_color.v > 0.5 else "dark"
	var base_icon: Texture2D = load("res://addons/dialogue_manager/assets/icons/icon_%s.svg" % theme)
	var image: Image = base_icon.get_image()
	
	control.free()
	
	image.resize(size.x, size.y, Image.INTERPOLATE_TRILINEAR)
	return ImageTexture.create_from_image(image)

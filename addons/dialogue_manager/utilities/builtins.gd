extends Object


const DialogueConstants = preload("../constants.gd")

const SUPPORTED_BUILTIN_TYPES = [
	TYPE_ARRAY,
	TYPE_VECTOR2,
	TYPE_VECTOR3,
	TYPE_VECTOR4,
	TYPE_DICTIONARY,
	TYPE_QUATERNION,
	TYPE_COLOR,
	TYPE_SIGNAL
]


static var resolve_method_error: Error = OK


static func is_supported(thing) -> bool:
	return typeof(thing) in SUPPORTED_BUILTIN_TYPES


static func resolve_property(builtin, property: String):
	match typeof(builtin):
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_QUATERNION:
			return builtin[property]

		# Some types have constants that we need to manually resolve

		TYPE_VECTOR2:
			return resolve_vector2_property(builtin, property)
		TYPE_VECTOR3:
			return resolve_vector3_property(builtin, property)
		TYPE_VECTOR4:
			return resolve_vector4_property(builtin, property)
		TYPE_COLOR:
			return resolve_color_property(builtin, property)


static func resolve_method(thing, method_name: String, args: Array):
	resolve_method_error = OK

	# Resolve static methods manually
	match typeof(thing):
		TYPE_VECTOR2:
			match method_name:
				"from_angle":
					return Vector2.from_angle(args[0])

		TYPE_COLOR:
			match method_name:
				"from_hsv":
					return Color.from_hsv(args[0], args[1], args[2]) if args.size() == 3 else Color.from_hsv(args[0], args[1], args[2], args[3])
				"from_ok_hsl":
					return Color.from_ok_hsl(args[0], args[1], args[2]) if args.size() == 3 else Color.from_ok_hsl(args[0], args[1], args[2], args[3])
				"from_rgbe9995":
					return Color.from_rgbe9995(args[0])
				"from_string":
					return Color.from_string(args[0], args[1])

		TYPE_QUATERNION:
			match method_name:
				"from_euler":
					return Quaternion.from_euler(args[0])

	# Anything else can be evaulatated automatically
	var references: Array = ["thing"]
	for i in range(0, args.size()):
		references.append("arg%d" % i)
	var expression = Expression.new()
	if expression.parse("thing.%s(%s)" % [method_name, ",".join(references.slice(1))], references) != OK:
		assert(false, expression.get_error_text())
	var result = expression.execute([thing] + args, null, false)
	if expression.has_execute_failed():
		resolve_method_error = ERR_CANT_RESOLVE
		return null

	return result


static func has_resolve_method_failed() -> bool:
	return resolve_method_error != OK


static func resolve_color_property(color: Color, property: String):
	match property:
		"ALICE_BLUE":
			return Color.ALICE_BLUE
		"ANTIQUE_WHITE":
			return Color.ANTIQUE_WHITE
		"AQUA":
			return Color.AQUA
		"AQUAMARINE":
			return Color.AQUAMARINE
		"AZURE":
			return Color.AZURE
		"BEIGE":
			return Color.BEIGE
		"BISQUE":
			return Color.BISQUE
		"BLACK":
			return Color.BLACK
		"BLANCHED_ALMOND":
			return Color.BLANCHED_ALMOND
		"BLUE":
			return Color.BLUE
		"BLUE_VIOLET":
			return Color.BLUE_VIOLET
		"BROWN":
			return Color.BROWN
		"BURLYWOOD":
			return Color.BURLYWOOD
		"CADET_BLUE":
			return Color.CADET_BLUE
		"CHARTREUSE":
			return Color.CHARTREUSE
		"CHOCOLATE":
			return Color.CHOCOLATE
		"CORAL":
			return Color.CORAL
		"CORNFLOWER_BLUE":
			return Color.CORNFLOWER_BLUE
		"CORNSILK":
			return Color.CORNSILK
		"CRIMSON":
			return Color.CRIMSON
		"CYAN":
			return Color.CYAN
		"DARK_BLUE":
			return Color.DARK_BLUE
		"DARK_CYAN":
			return Color.DARK_CYAN
		"DARK_GOLDENROD":
			return Color.DARK_GOLDENROD
		"DARK_GRAY":
			return Color.DARK_GRAY
		"DARK_GREEN":
			return Color.DARK_GREEN
		"DARK_KHAKI":
			return Color.DARK_KHAKI
		"DARK_MAGENTA":
			return Color.DARK_MAGENTA
		"DARK_OLIVE_GREEN":
			return Color.DARK_OLIVE_GREEN
		"DARK_ORANGE":
			return Color.DARK_ORANGE
		"DARK_ORCHID":
			return Color.DARK_ORCHID
		"DARK_RED":
			return Color.DARK_RED
		"DARK_SALMON":
			return Color.DARK_SALMON
		"DARK_SEA_GREEN":
			return Color.DARK_SEA_GREEN
		"DARK_SLATE_BLUE":
			return Color.DARK_SLATE_BLUE
		"DARK_SLATE_GRAY":
			return Color.DARK_SLATE_GRAY
		"DARK_TURQUOISE":
			return Color.DARK_TURQUOISE
		"DARK_VIOLET":
			return Color.DARK_VIOLET
		"DEEP_PINK":
			return Color.DEEP_PINK
		"DEEP_SKY_BLUE":
			return Color.DEEP_SKY_BLUE
		"DIM_GRAY":
			return Color.DIM_GRAY
		"DODGER_BLUE":
			return Color.DODGER_BLUE
		"FIREBRICK":
			return Color.FIREBRICK
		"FLORAL_WHITE":
			return Color.FLORAL_WHITE
		"FOREST_GREEN":
			return Color.FOREST_GREEN
		"FUCHSIA":
			return Color.FUCHSIA
		"GAINSBORO":
			return Color.GAINSBORO
		"GHOST_WHITE":
			return Color.GHOST_WHITE
		"GOLD":
			return Color.GOLD
		"GOLDENROD":
			return Color.GOLDENROD
		"GRAY":
			return Color.GRAY
		"GREEN":
			return Color.GREEN
		"GREEN_YELLOW":
			return Color.GREEN_YELLOW
		"HONEYDEW":
			return Color.HONEYDEW
		"HOT_PINK":
			return Color.HOT_PINK
		"INDIAN_RED":
			return Color.INDIAN_RED
		"INDIGO":
			return Color.INDIGO
		"IVORY":
			return Color.IVORY
		"KHAKI":
			return Color.KHAKI
		"LAVENDER":
			return Color.LAVENDER
		"LAVENDER_BLUSH":
			return Color.LAVENDER_BLUSH
		"LAWN_GREEN":
			return Color.LAWN_GREEN
		"LEMON_CHIFFON":
			return Color.LEMON_CHIFFON
		"LIGHT_BLUE":
			return Color.LIGHT_BLUE
		"LIGHT_CORAL":
			return Color.LIGHT_CORAL
		"LIGHT_CYAN":
			return Color.LIGHT_CYAN
		"LIGHT_GOLDENROD":
			return Color.LIGHT_GOLDENROD
		"LIGHT_GRAY":
			return Color.LIGHT_GRAY
		"LIGHT_GREEN":
			return Color.LIGHT_GREEN
		"LIGHT_PINK":
			return Color.LIGHT_PINK
		"LIGHT_SALMON":
			return Color.LIGHT_SALMON
		"LIGHT_SEA_GREEN":
			return Color.LIGHT_SEA_GREEN
		"LIGHT_SKY_BLUE":
			return Color.LIGHT_SKY_BLUE
		"LIGHT_SLATE_GRAY":
			return Color.LIGHT_SLATE_GRAY
		"LIGHT_STEEL_BLUE":
			return Color.LIGHT_STEEL_BLUE
		"LIGHT_YELLOW":
			return Color.LIGHT_YELLOW
		"LIME":
			return Color.LIME
		"LIME_GREEN":
			return Color.LIME_GREEN
		"LINEN":
			return Color.LINEN
		"MAGENTA":
			return Color.MAGENTA
		"MAROON":
			return Color.MAROON
		"MEDIUM_AQUAMARINE":
			return Color.MEDIUM_AQUAMARINE
		"MEDIUM_BLUE":
			return Color.MEDIUM_BLUE
		"MEDIUM_ORCHID":
			return Color.MEDIUM_ORCHID
		"MEDIUM_PURPLE":
			return Color.MEDIUM_PURPLE
		"MEDIUM_SEA_GREEN":
			return Color.MEDIUM_SEA_GREEN
		"MEDIUM_SLATE_BLUE":
			return Color.MEDIUM_SLATE_BLUE
		"MEDIUM_SPRING_GREEN":
			return Color.MEDIUM_SPRING_GREEN
		"MEDIUM_TURQUOISE":
			return Color.MEDIUM_TURQUOISE
		"MEDIUM_VIOLET_RED":
			return Color.MEDIUM_VIOLET_RED
		"MIDNIGHT_BLUE":
			return Color.MIDNIGHT_BLUE
		"MINT_CREAM":
			return Color.MINT_CREAM
		"MISTY_ROSE":
			return Color.MISTY_ROSE
		"MOCCASIN":
			return Color.MOCCASIN
		"NAVAJO_WHITE":
			return Color.NAVAJO_WHITE
		"NAVY_BLUE":
			return Color.NAVY_BLUE
		"OLD_LACE":
			return Color.OLD_LACE
		"OLIVE":
			return Color.OLIVE
		"OLIVE_DRAB":
			return Color.OLIVE_DRAB
		"ORANGE":
			return Color.ORANGE
		"ORANGE_RED":
			return Color.ORANGE_RED
		"ORCHID":
			return Color.ORCHID
		"PALE_GOLDENROD":
			return Color.PALE_GOLDENROD
		"PALE_GREEN":
			return Color.PALE_GREEN
		"PALE_TURQUOISE":
			return Color.PALE_TURQUOISE
		"PALE_VIOLET_RED":
			return Color.PALE_VIOLET_RED
		"PAPAYA_WHIP":
			return Color.PAPAYA_WHIP
		"PEACH_PUFF":
			return Color.PEACH_PUFF
		"PERU":
			return Color.PERU
		"PINK":
			return Color.PINK
		"PLUM":
			return Color.PLUM
		"POWDER_BLUE":
			return Color.POWDER_BLUE
		"PURPLE":
			return Color.PURPLE
		"REBECCA_PURPLE":
			return Color.REBECCA_PURPLE
		"RED":
			return Color.RED
		"ROSY_BROWN":
			return Color.ROSY_BROWN
		"ROYAL_BLUE":
			return Color.ROYAL_BLUE
		"SADDLE_BROWN":
			return Color.SADDLE_BROWN
		"SALMON":
			return Color.SALMON
		"SANDY_BROWN":
			return Color.SANDY_BROWN
		"SEA_GREEN":
			return Color.SEA_GREEN
		"SEASHELL":
			return Color.SEASHELL
		"SIENNA":
			return Color.SIENNA
		"SILVER":
			return Color.SILVER
		"SKY_BLUE":
			return Color.SKY_BLUE
		"SLATE_BLUE":
			return Color.SLATE_BLUE
		"SLATE_GRAY":
			return Color.SLATE_GRAY
		"SNOW":
			return Color.SNOW
		"SPRING_GREEN":
			return Color.SPRING_GREEN
		"STEEL_BLUE":
			return Color.STEEL_BLUE
		"TAN":
			return Color.TAN
		"TEAL":
			return Color.TEAL
		"THISTLE":
			return Color.THISTLE
		"TOMATO":
			return Color.TOMATO
		"TRANSPARENT":
			return Color.TRANSPARENT
		"TURQUOISE":
			return Color.TURQUOISE
		"VIOLET":
			return Color.VIOLET
		"WEB_GRAY":
			return Color.WEB_GRAY
		"WEB_GREEN":
			return Color.WEB_GREEN
		"WEB_MAROON":
			return Color.WEB_MAROON
		"WEB_PURPLE":
			return Color.WEB_PURPLE
		"WHEAT":
			return Color.WHEAT
		"WHITE":
			return Color.WHITE
		"WHITE_SMOKE":
			return Color.WHITE_SMOKE
		"YELLOW":
			return Color.YELLOW
		"YELLOW_GREEN":
			return Color.YELLOW_GREEN

	return color[property]


static func resolve_vector2_property(vector: Vector2, property: String):
	match property:
		"AXIS_X":
			return Vector2.AXIS_X
		"AXIS_Y":
			return Vector2.AXIS_Y
		"ZERO":
			return Vector2.ZERO
		"ONE":
			return Vector2.ONE
		"INF":
			return Vector2.INF
		"LEFT":
			return Vector2.LEFT
		"RIGHT":
			return Vector2.RIGHT
		"UP":
			return Vector2.UP
		"DOWN":
			return Vector2.DOWN

	return vector[property]


static func resolve_vector3_property(vector: Vector3, property: String):
	match property:
		"AXIS_X":
			return Vector3.AXIS_X
		"AXIS_Y":
			return Vector3.AXIS_Y
		"AXIS_Z":
			return Vector3.AXIS_Z
		"ZERO":
			return Vector3.ZERO
		"ONE":
			return Vector3.ONE
		"INF":
			return Vector3.INF
		"LEFT":
			return Vector3.LEFT
		"RIGHT":
			return Vector3.RIGHT
		"UP":
			return Vector3.UP
		"DOWN":
			return Vector3.DOWN
		"FORWARD":
			return Vector3.FORWARD
		"BACK":
			return Vector3.BACK

	return vector[property]


static func resolve_vector4_property(vector: Vector4, property: String):
	match property:
		"AXIS_X":
			return Vector4.AXIS_X
		"AXIS_Y":
			return Vector4.AXIS_Y
		"AXIS_Z":
			return Vector4.AXIS_Z
		"AXIS_W":
			return Vector4.AXIS_W
		"ZERO":
			return Vector4.ZERO
		"ONE":
			return Vector4.ONE
		"INF":
			return Vector4.INF

	return vector[property]

## Tag data associated with a line of dialogue.
class_name DMResolvedTagData extends RefCounted


## The list of tags.
var tags: PackedStringArray = []
## The line with any tag syntax removed.
var text_without_tags: String = ""

# An instance of the compiler [RegEx].
var regex: DMCompilerRegEx = DMCompilerRegEx.new()


func _init(text: String) -> void:
	var resolved_tags: PackedStringArray = []
	var tag_matches: Array[RegExMatch] = regex.TAGS_REGEX.search_all(text)
	for tag_match in tag_matches:
		text = text.replace(tag_match.get_string(), "")
		var tags = tag_match.get_string().replace("[#", "").replace("]", "").replace(", ", ",").split(",")
		for tag in tags:
			tag = tag.replace("#", "")
			if not tag in resolved_tags:
				resolved_tags.append(tag)

	tags = resolved_tags
	text_without_tags = text

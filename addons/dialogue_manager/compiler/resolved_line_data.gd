## Any data associated with inline dialogue BBCodes.
class_name DMResolvedLineData extends RefCounted

## The line's text
var text: String = ""
## A map of pauses against where they are found in the text.
var pauses: Dictionary = {}
## A map of speed changes against where they are found in the text.
var speeds: Dictionary = {}
## A list of any mutations to run and where they are found in the text.
var mutations: Array[Array] = []
## A duration reference for the line. Represented as "auto" or a stringified number.
var time: String = ""


func _init(line: String) -> void:
	text = line
	pauses = {}
	speeds = {}
	mutations = []
	time = ""

	var bbcodes: Array = []

	# Remove any escaped brackets (ie. "\[")
	var escaped_open_brackets: PackedInt32Array = []
	var escaped_close_brackets: PackedInt32Array = []
	for i in range(0, text.length() - 1):
		if text.substr(i, 2) == "\\[":
			text = text.substr(0, i) + "!" + text.substr(i + 2)
			escaped_open_brackets.append(i)
		elif text.substr(i, 2) == "\\]":
			text = text.substr(0, i) + "!" + text.substr(i + 2)
			escaped_close_brackets.append(i)

	# Extract all of the BB codes so that we know the actual text (we could do this easier with
	# a RichTextLabel but then we'd need to await idle_frame which is annoying)
	var bbcode_positions = find_bbcode_positions_in_string(text)
	var accumulaive_length_offset = 0
	for position in bbcode_positions:
		# Ignore our own markers
		if position.code in ["wait", "speed", "/speed", "do", "do!", "set", "next", "if", "else", "/if"]:
			continue

		bbcodes.append({
			bbcode = position.bbcode,
			start = position.start,
			offset_start = position.start - accumulaive_length_offset
		})
		accumulaive_length_offset += position.bbcode.length()

	for bb in bbcodes:
		text = text.substr(0, bb.offset_start) + text.substr(bb.offset_start + bb.bbcode.length())

	# Now find any dialogue markers
	var next_bbcode_position = find_bbcode_positions_in_string(text, false)
	var limit = 0
	while next_bbcode_position.size() > 0 and limit < 1000:
		limit += 1

		var bbcode = next_bbcode_position[0]

		var index = bbcode.start
		var code = bbcode.code
		var raw_args = bbcode.raw_args
		var args = {}
		if code in ["do", "do!", "set"]:
			var compilation: DMCompilation = DMCompilation.new()
			args["value"] = compilation.extract_mutation("%s %s" % [code, raw_args])
		else:
			# Could be something like:
			# 	"=1.0"
			# 	" rate=20 level=10"
			if raw_args and raw_args[0] == "=":
				raw_args = "value" + raw_args
			for pair in raw_args.strip_edges().split(" "):
				if "=" in pair:
					var bits = pair.split("=")
					args[bits[0]] = bits[1]

		match code:
			"wait":
				if pauses.has(index):
					pauses[index] += args.get("value").to_float()
				else:
					pauses[index] = args.get("value").to_float()
			"speed":
				speeds[index] = args.get("value").to_float()
			"/speed":
				speeds[index] = 1.0
			"do", "do!", "set":
				mutations.append([index, args.get("value")])
			"next":
				time = args.get("value") if args.has("value") else "0"

		# Find any BB codes that are after this index and remove the length from their start
		var length = bbcode.bbcode.length()
		for bb in bbcodes:
			if bb.offset_start > bbcode.start:
				bb.offset_start -= length
				bb.start -= length

		# Find any escaped brackets after this that need moving
		for i in range(0, escaped_open_brackets.size()):
			if escaped_open_brackets[i] > bbcode.start:
				escaped_open_brackets[i] -= length
		for i in range(0, escaped_close_brackets.size()):
			if escaped_close_brackets[i] > bbcode.start:
				escaped_close_brackets[i] -= length

		text = text.substr(0, index) + text.substr(index + length)
		next_bbcode_position = find_bbcode_positions_in_string(text, false)

	# Put the BB Codes back in
	for bb in bbcodes:
		text = text.insert(bb.start, bb.bbcode)

	# Put the escaped brackets back in
	for index in escaped_open_brackets:
		text = text.left(index) + "[" + text.right(text.length() - index - 1)
	for index in escaped_close_brackets:
		text = text.left(index) + "]" + text.right(text.length() - index - 1)


func find_bbcode_positions_in_string(string: String, find_all: bool = true) -> Array[Dictionary]:
	if not "[" in string: return []

	var positions: Array[Dictionary] = []

	var open_brace_count: int = 0
	var start: int = 0
	var bbcode: String = ""
	var code: String = ""
	var is_finished_code: bool = false
	for i in range(0, string.length()):
		if string[i] == "[":
			if open_brace_count == 0:
				start = i
				bbcode = ""
				code = ""
				is_finished_code = false
			open_brace_count += 1

		else:
			if not is_finished_code and (string[i].to_upper() != string[i] or string[i] == "/" or string[i] == "!"):
				code += string[i]
			else:
				is_finished_code = true

		if open_brace_count > 0:
			bbcode += string[i]

		if string[i] == "]":
			open_brace_count -= 1
			if open_brace_count == 0 and not code in ["if", "else", "/if"]:
				positions.append({
					bbcode = bbcode,
					code = code,
					start = start,
					raw_args = bbcode.substr(code.length() + 1, bbcode.length() - code.length() - 2).strip_edges()
				})

				if not find_all:
					return positions

	return positions

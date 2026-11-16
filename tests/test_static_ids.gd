extends AbstractTest


func test_can_generate_static_ids() -> void:
	var text: String = ""

	for line: String in [
		"Dialogue without character.",
		"Nathan: Dialogue with a character.",
		"- [if condition/][#tag] First Response",
		"- [#tag] Second Response",
		"- Third Response [#tag]",
		"- Fourth Response [#tag] [if condition/]",
		"- Fifth Response [if condition/][#tag]"
	]:
		text = DMTranslationUtilities.generate_static_line_ids_for_text(line, ".")
		assert(text.contains("[ID:"), "Should include a static ID.")

	for ignored_line: String in [
		"~ cue",
		"$> mutation()"
	]:
		text = DMTranslationUtilities.generate_static_line_ids_for_text(ignored_line, ".")
		assert(not text.contains("[ID:"), "Should not include a static ID.")


func test_can_get_csv_keys_for_lines() -> void:
	var setting_name: String = "dialogue_manager/%s" % DMSettings.USE_STATIC_IDS_AS_TRANSLATION_KEYS
	var original_value: Variant = ProjectSettings.get_setting(setting_name) if ProjectSettings.has_setting(setting_name) else null

	var lines: Dictionary = DMCompiler.compile_string("
~ start
Queen: Welcome. [ID:QUEEN_GREET]
Queen: No ID.
- Yes please [ID:Q_YES]
- No thanks
=> END", "").lines

	ProjectSettings.set_setting(setting_name, true)
	var keys: Array = _get_csv_keys(lines)
	assert(keys == ["QUEEN_GREET", "No ID.", "Q_YES", "No thanks"], "Should use static IDs where there are any.")

	ProjectSettings.set_setting(setting_name, false)
	keys = _get_csv_keys(lines)
	assert(keys == ["Welcome.", "No ID.", "Yes please", "No thanks"], "Should use text when static IDs aren't keys.")

	ProjectSettings.set_setting(setting_name, original_value)


func _get_csv_keys(lines: Dictionary) -> Array:
	var keys: Array = []
	for line: Dictionary in lines.values():
		if not line.type in [DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RESPONSE]: continue
		keys.append(DMTranslationUtilities.get_csv_key_for_line(line))
	return keys

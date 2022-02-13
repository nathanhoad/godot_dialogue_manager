# Translations

By default, all dialogue and response prompts will be run through Godot's `tr` function to provide translations. 

You can turn this off by setting `DialogueManager.auto_translate = false` but beware, if it is off you may need to handle your own variable replacements if using manual translation keys. You can use `DialogueManager.replace_values(line)` or `DialogueManager.replace_values(response)` to replace text variable markers with their values.

This might be useful for cases where you have audio dialog files that match up with lines.

## Static translation keys in dialog

You can export translations as CSV from the "Translations" menu in the dialog editor. 

This will find any unique dialog lines or response prompts and add them to a list. If a static key is specified for the line (eg. `[TR:SOME_KEY]`) then that will be used as the translation key, otherwise the dialog/prompt itself will be used.

If the target CSV file already exists, it will be merged with it.

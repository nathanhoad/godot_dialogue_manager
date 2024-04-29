# Settings

## Editor

- `New dialogue files will start with template text` can be enabled to start new dialogue files with example dialogue.
- `Export character names in translation files` can be enabled to include character names when using translations.
- `Wrap long lines` turns on word wrapping.
- `Default CSV locale` can be modified to set the default locale heading when generating CSVs for translation.

## Runtime

- `Include responses with failed conditions` will include responses that failed their condition check in the list of responses attached to a given line.
- `Skip over missing state value errors` will let you run dialogue and ignore any errors that occur when you reference state values that don't exist.

### Custom balloon

You can configure a default balloon to show when calling [`DialogueManager.show_dialogue_balloon()`](./API.md#func-show_dialogue_balloonresource-dialogueresource-title-string--0-extra_game_states-array-----node). This balloon will also be used when testing dialogue from the dialogue editor.

### Globals shortcuts

The dialogue runtime itself is stateless, meaning it looks to your game to provide values for variables and for methods to run. At run time, the dialogue manager will check the current scene first and then check any globals.

If you don't want to type out a globals' name all of the time you can add it to the globals shortcut list.

For example, instead of having to type out `GameState.some_variable`, you could enable `GameState` and then you would just need to type out `some_variable`.

![GameState and SessionState are used by dialogue](states.jpg)

## Advanced

- `Include character names in translation exports` - will include a `_character` column in CSV exports.
- `Include notes (## comments) in translation exports` - will include a `_notes` column in CSV exports populated from doc-style comments (eg. `## This is a comment`) above translatable lines.
- `Custom Test Scene` can be used to override the default test scene that gets run when you click the "Test dialogue" button in the dialogue editor.

Changing any of the following values will result in a recompile of all dialogue files in your project.

- `Treat missing translations as errors` can be enabled if you are using static translation keys and are adding them manually (there is an automatic static key button but you might be writing specific keys).
- `Create child dialogue line for responses with character names in them` can be disabled if you don't want to automatically create a dialogue line after responses that define a character

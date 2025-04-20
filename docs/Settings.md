
# Settings

Dialogue Manager settings are found in Project Settings at the bottom of the General tab.

## Runtime

- **State Autoload Shortcuts**

  An array of autoload names that you want to have shortcuts to in your dialogue. For example, if you had a `SomeGlobal` autoload that had a `some_property` property you might refer to it in dialogue like this:

  ```
  if SomeGlobal.some_property > 0:
    Nathan: There are {{SomeGlobal.some_property}} of them!
  ```

  But if you added "SomeGlobal" to the list of State Autoload Shortcuts then in your dialogue you could just write it as:

  ```
  if some_property > 0:
    Nathan: There are {{some_property}} of them!
  ```

- **Warn about method property or signal name conflicts** (Advanced)

  If enabled, when there is more than one property, method, or signal sharing the same name at the top-level (ie. extra game states, current scene, or autoload shortcut) a warning will be shown in the Debugger panel.

  _NOTE: Even when enabled, this does nothing when running in a non-debug build._

- **Balloon Path**

  The balloon scene to instantiate when using `DialogueManager.show_dialogue_balloon`.

- **Ignore Missing State Values** (Advanced)

  Suppress errors when properties or mutations are missing from state.

## Editor

- **Wrap Long Lines**

  Wrap lines in the dialogue editor instead of horizontally scrolling.

- **New File Template**

  Start new dialogue files with this content by default.

- **Missing Translations Are Errors**

  Any lines that don't have a static ID will be treated as erroneous.

- **Include Characters in Translatable Strings List**

  Include any charactter names in the POT export.

- **Default Csv Locale**

  The default locale to use when first exporting a translations CSV.

- **Include Character in Translation Exports** (advanced)

  Include a _\_character_ column in CSV exports that shows which character was speaking the line of dialogue.

- **Include Notes in Translation Exports** (advanced)

  Include a _\_notes_ column in CSV exports for doc comments.

- **Custom Test Scene Path** (advanced)

  Use a custom test scene when running "Test" from the dialogue editor. The scene must extend `BaseDialogueTestScene`.

- **Extra Auto Complete Script Sources** (advanced)

  Add script files to check for top level auto-complete members.

  Any scripts added in here are assumed to be available in all dialogue files (eg. your balloon inserts itself into the `extra_game_states` at runtime).
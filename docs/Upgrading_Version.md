# Upgrading major versions

Before updating between versions of Dialogue Manager you should always make sure you've commited any other changes in your game to source control. Major upgrades aren't always necessary and with a clean source control state you can experiment with the upgrade and roll back if the upgrade is too much effort (especially if you're well into development of the game).

When doing a major version upgrade there are probably things that you'll need to change manually before everything works again. It's usually also recommended that you delete your `.godot` cache folder and then restart the Godot editor a couple of times to get it to recreate the cache properly.

## v3 to v4

Godot 4.6 is now the minimum Godot version supported.

### Breaking changes

- "Titles" are now called "Cues" to better reflect how they are used.
- Response Conditions are now self-closing (eg. `- Text [if some_condition]` is now `- Text [if some_condition /]`).
- The `translation_key` property of `DialogueLine`s is now `static_id` to better reflect that it's not just for translations.
- When exporting translation templates from Godot, the line's `static_id` will be used as the translation key if it has one (previously, they'd be used as context but context is now always just "dialogue").

### Possible gotchas

- The bespoke CSV exporter has been removed in favour of Godot's built-in translation template exporter (in **Project Settings > Localisation > Template Generation**) now supporting CSVs.
- The `raw_text` property of `DialogueResource` files has been removed.

## v2 to v3

The upgrade should be mostly seamless but there are a couple of things to watch out for:

- Dialogue Manager 3 requires Godot 4.3 or above.
- The "include failed responses" setting has been removed and is now the default. Responses that fail their condition check will be included in the responses list and it is now up to the balloon to filter them out. The provided `DialogueResponsesMenu` node has an option to hide failed responses.
- The "create lines for responses with characters" setting is now gone and something your game will have to do manually.
- The built-in `emit` mutation has been removed in favour of emitting signals just like GDScript (ie. `some_signal.emit()`).

To upgrade from 2.x to 3.x you can remove the `addons/dialogue_manager` directory and then download a fresh copy of Dialogue Manager 3 from either the Asset Library or GitHub.
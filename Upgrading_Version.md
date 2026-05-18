# Upgrading from Dialogue Manager 2 to Dialogue Manager 3

The upgrade should be mostly seamless but there are a couple of things to watch out for:

- Dialogue Manager 3 requires Godot 4.3 or above.
- The "include failed responses" setting has been removed and is now the default. Responses that fail their condition check will be included in the responses list and it is now up to the balloon to filter them out. The provided `DialogueResponsesMenu` node has an option to hide failed responses.
- The "create lines for responses with characters" setting is now gone and something your game will have to do manually.
- The built-in `emit` mutation has been removed in favour of emitting signals just like GDScript (ie. `some_signal.emit()`).

To upgrade from 2.x to 3.x you can remove the `addons/dialogue_manager` directory and then download a fresh copy of Dialogue Manager 3 from either the Asset Library or GitHub.

# Upgrading from Dialogue Manager 3 to Dialogue Manager 4

Godot 4.6 is now the minimum Godot version supported.
Breaking changes

    "Titles" are now called "Cues" to better reflect how they are used.
    Response Conditions are now self-closing (eg. - Text [if some_condition] is now - Text [if some_condition /]).
    The translation_key property of DialogueLines is now static_id to better reflect that it's not just for translations.

Possible gotchas

    The bespoke CSV exporter has been removed in favour of Godot's built-in translation template exporter (in Project Settings > Localisation > Template Generation) now supporting CSVs.
    The raw_text property of DialogueResource files has been removed.

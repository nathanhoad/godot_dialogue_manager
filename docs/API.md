# API

## `DialogueManager`

### Signals

- `dialogue_started(resource: DialogueResource)` - emitted when a dialogue balloon is created and dialogue begins.
- `passed_title(title)` - emitted when a title marker is passed through.
- `got_dialogue(line: DialogueLine)` - emitted when a dialogue line is found.
- `mutated(mutation: Dictionary)` - emitted when a mutation line is about to be run (not including `set` lines).
- `dialogue_ended(resource: DialogueResource)` - emitted when the next line of dialogue is empty and provides the calling resource.

### Methods

#### `func show_dialogue_balloon(resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> Node`

Opens the dialogue balloon configured in settings (or the example balloon if none has been set).

Returns the balloon's base node in case you want to `queue_free()` it yourself.

#### `func show_dialogue_balloon_scene(balloon_scene: Node | String, resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> Node`

Opens a dialogue balloon given in `balloon_scene`.

Returns the balloon's base node in case you want to `queue_free()` it yourself.

#### `func get_next_dialogue_line(resource: DialogueResource, key: String = "", extra_game_states: Array = [], mutation_behaviour: MutationBehaviour = MutationBehaviour.Wait) -> DialogueLine`

**Must be used with `await`.**

Given a resource and title/ID, it will find the next printable line of dialogue (running mutations along the way).

Returns a `DialogueLine` that looks something like this:

- `id: String` - the ID of the line.
- `next_id: String` - the ID of the next line of dialogue after this one.
- `character: String` - the name of the character speaking (or `""`).
- `text: String` - the text that the character is saying.
- `tags: PackedStringArray` - a list of tags.
- `translation_key: String` - the key used to translate the text (or the whole text again if no ID was specified on the line).
- `responses: Array[DialogueResponse]` - the list of responses to this line (or `[]` if none are available).
  - `id: String` - the ID of the response.
  - `next_id: String` - the ID of the next line if this response is chosen.
  - `is_allowed: bool` - whether this line passed its condition check (useful if you have "include all responses" enabled).
  - `character: String` - the character name (if one was provided).
  - `text: String` - the text for this response.
  - `tags: PackedStringArray` - a list of tags.
  - `translation_key: String` - the key used to translate the text (or the whole text again if no ID was specified on the response).
- `concurrent_lines: Array[DialogueLine]` - A list of lines that are to be spoken at the same time as this one.

If there is no next line of dialogue found, it will return an empty dictionary (`{}`).

Pass an array of nodes as `extra_game_states` in order to temporarily add to the game state shortcuts that are available to conditions and mutations.

You can specify `mutation_behaviour` to be one of the values provided in the `DialogueManager.MutationBehaviour` enum. `Wait` is the default and will `await` any mutation lines. `DoNoWait` will run the mutations but not wait for them before moving to the next line. `Skip` will skip mutations entirely. In most cases, you should leave this as the default. _The example balloon only supports `Wait`_.

#### `func show_example_dialogue_balloon(resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> CanvasLayer`

Opens the example balloon.

If your game viewport is less than 400, it will open the low res balloon. Otherwise, it will open the usual balloon.

It will close once dialogue runs out.

Returns the example balloon's base CanvasLayer in case you want to `queue_free()` it yourself.

## `DialogueLabel`

### Exports

- `seconds_per_step: float = 0.02` - the speed at which the text types out.
- `pause_at_characters: String = ".?!"` - automatically have a brief pause when these characters are encountered.
- `skip_pause_at_character_if_followed_by: String = ")\""` - ignore automatic pausing if the pause character is followed by one of these.
- `skip_pause_at_abbreviations: Array = ["Mr", "Mrs", "Ms", "Dr", "etc", "ex"]` - don't auto pause after these abbreviations (only if "." is in `pause_at_characters`).
- `seconds_per_pause_step: float = 0.3` - the amount of time to pause when exposing a character present in pause_at_characters.

### Signals

- `spoke(letter: String, letter_index: int, speed: float)` - emitted each step while typing out.
- `paused_typing(duration: float)` - emitted when the label pauses typing.
- `skipped_typing()` - emitted when the player skips the label typing out.
- `finished_typing()` - emitted when the label finishes typing.

### Methods

#### `func type_out() -> void`

Starts typing out the text of the label.

#### `func skip_typing() -> void`

Stop typing out the text and jump right to the end. This will emit `skipped_typing`.

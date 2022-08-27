# API

## `DialogueManager`

### Signals

- `dialogue()` - emitted when a dialogue line is found.
- `mutation()` - emitted when a mutation line is about to be run (not including `set` lines).
- `dialogue_finished()` - emitted when there is no more dialogue to run.

### Methods

#### `func get_next_dialogue_line(resource: Resource, key: String = "0", extra_game_states: Array = []) -> Dictionary`

Must be used with `await`.

Given a resource and title/ID, it will find the next printable line of dialogue (running mutations along the way).

Returns a dialogue line dictionary that looks something like this:

- `next_id: String` - the ID of the next line of dialogue after this one.
- `character: String` - the name of the character speaking (or `""`).
- `text: String` - the text that the character is saying.
- `translation_key: String` - the key used to translate the text (or the whole text again if no ID was specified on the line)
- `responses: Array[Dictionary]` - the list of responses to this line (or `[]` if none are available).
  - `next_id: String` - the ID of the next line if this response is chosen.
  - `is_allowed: bool` - whether this line passed its condition check (useful if you have "include all responses" enabled)
  - `text: String` - the text for this response.
  - `translation_key: String` - the key used to translate the text (or the whole text again if no ID was specified on the response)

If there is no next line of dialogue found then it will return an empty dictionary (`{}`).

Pass an array of nodes as `extra_game_states` in order to temporarily add to the game state shortcuts that are available to conditions and mutations.

#### `func show_example_dialogue_balloon(resource: Resource, title: String = "0", extra_game_states: Array = []) -> void`

Opens the example balloon.

If your game viewport is less than 400 it will open the low res balloon. Otherwise it will open the usual balloon.

It will close once dialogue runs out.

## `DialogueLabel`

### Exports

- `skip_action: String = "ui_cancel"` - the action to press to skip typing.
- `seconds_per_step: float = 0.02` - the speed with which the text types out.
- `start_with_full_height: bool = true` - when off, the label will grow in height as the text types out.

### Signals

- `spoke(letter: String, letter_index: int, speed: float)` - emitted each step while typing out.
- `paused_typing(duration: float)` - emitted when the label pauses typing
- `finished_typing()` - emitted when the label finishes typing

### Methods

#### `func reset_height() -> void`

Recalculates the minimum height of the label. Useful when the label is a child of a container.

#### `func type_out() -> void`

Starts typing out the text of the label.
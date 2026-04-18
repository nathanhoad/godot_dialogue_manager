# API

## `DialogueManager`

### Signals

- `dialogue_started(resource: DialogueResource)` - emitted when a dialogue balloon is created by `DialogueManager` and dialogue begins.
- `passed_Cue(Cue: String)` - emitted when a Cue marker is passed through.
- `got_dialogue(line: DialogueLine)` - emitted when a dialogue line is found.
- `mutated(mutation: Dictionary)` - emitted when a mutation line is about to be run (not including `set` lines).
- `dialogue_ended(resource: DialogueResource)` - emitted when the next line of dialogue is empty and provides the calling resource.

### Methods

#### `func show_dialogue_balloon(resource: DialogueResource, Cue: String = "", extra_game_states: Array = []) -> Node`

Opens the dialogue balloon configured in settings (or the example balloon if none has been set).

Returns the balloon's base node in case you want to `queue_free()` it yourself.

#### `func show_dialogue_balloon_scene(balloon_scene: Node | String, resource: DialogueResource, Cue: String = "", extra_game_states: Array = []) -> Node`

Opens a dialogue balloon given in `balloon_scene`.

Returns the balloon's base node in case you want to `queue_free()` it yourself.

#### `func get_next_dialogue_line(resource: DialogueResource, key: String = "", extra_game_states: Array = [], mutation_behaviour: MutationBehaviour = MutationBehaviour.Wait) -> DialogueLine`

> [!IMPORTANT]
> Must be used with `await`.

Given a resource and Cue/key, it will find the next printable line of dialogue (running mutations along the way unless `mutation_behaviour` is overriden).

Returns a `DialogueLine` or `null`.

Pass an array of nodes/dictionaries as `extra_game_states` in order to temporarily add to the game state shortcuts that are available to conditions and mutations.

You can specify `mutation_behaviour` to be one of the values provided in the `DialogueManager.MutationBehaviour` enum. `Wait` is the default and will `await` any mutation lines. `DoNoWait` will run the mutations but not wait for them before moving to the next line. `Skip` will skip mutations entirely. In most cases, you should leave this as the default. 

> [!NOTE]
> The example balloon only supports `Wait`.

#### `func show_example_dialogue_balloon(resource: DialogueResource, Cue: String = "", extra_game_states: Array = []) -> CanvasLayer`

Opens the example balloon.

If your game viewport is less than 400, it will open the low res balloon. Otherwise, it will open the usual balloon.

It will close once dialogue runs out.

Returns the example balloon's base CanvasLayer in case you want to `queue_free()` it yourself.

## `DialogueLine`

A line of dialogue.

- `id: String` - the ID of the line.
- `next_id: String` - the ID of the next line of dialogue after this one.
- `character: String` - the name of the character speaking (or `""`).
- `text: String` - the text that the character is saying.
- `tags: PackedStringArray` - a list of tags.
- `static_id: String` - the key used to translate the text (or the whole text again if no ID was specified on the line).
- `responses: Array[DialogueResponse]` - the list of responses to this line (or `[]` if none are available).
  - `id: String` - the ID of the response.
  - `next_id: String` - the ID of the next line if this response is chosen.
  - `is_allowed: bool` - whether this line passed its condition check.
  - `condition_as_text: String` - the original condition (as a string) used to check if this response is allowed.
  - `character: String` - the character name (or `""`).
  - `text: String` - the text for this response.
  - `tags: PackedStringArray` - a list of tags.
  - `static_id: String` - the key used to translate the text (or the whole text again if no ID was specified on the response).
- `concurrent_lines: Array[DialogueLine]` - A list of lines that are to be spoken at the same time as this one.

#### `func to_serialized() -> String`

Convert a line of dialogue to a string that can be used to restore it later.

#### `static func new_from_serialized(serialized_string: String, extra_game_states: Array = []) -> DialogueLine`

Restore a serialized line of dialogue. Pass in an array of game states if needed.

> [!WARNING]
> Serializing only works with persisted resources, not resources that have been created with `DialogueManager.create_resource_from_text()`.


## Nodes

See [Nodes](./Nodes.md)
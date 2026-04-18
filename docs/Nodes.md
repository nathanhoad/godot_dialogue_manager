# Nodes

Dialogue Manager provides a few nodes to make things easier to use dialogue in your game.

## `Actionable2D` and `Actionable3D`

These are extensions of `Area2D` and `Area3D` that help initiate dialogue.

### Signals

#### `actioned()`

Emitted when this actionable has `action()` called on it.

#### `dialogue_ended()`

Emitted when the `DialogueResource` associated with this actionable ends.

> [!WARNING]
> The signal is also emitted if the same resource is used for multiple actionable nodes in the tree.

### Properties

#### `dialogue_resource: DialogueResource = null`

The [DialogueResource] to use when starting dialogue.

#### `dialogue_cue: String = ""`

The target cue to start dialogue from.

#### `dialogue_balloon: Node`

The dialogue balloon that was last used by calling `action()` (if there was one).

#### `static start_dialogue: Callable = func(with_dialogue_resource: DialogueResource, from_cue: String, extra_game_states: Array) -> Node2D`

The method used to start dialogue action `action()` is called. Override if you need different logic.

### Methods

`action() -> void`

Action this actionable. If a `DialogueResource` and cue have been set on this node then it will start dialogue.

#### `static get_nearest_actionable_to(target_position: Vector2) -> Actionable2D` (or `Actionable3D)

Find the nearest actionable to a given position.

## `DialogueMarker2D` and `DialogueMaker3D`

These are used in your character scenes to help mark a character's position relative to the viewport. You can also use them as an origin point for a speech balloon style dialogue balloon.

### Properties

#### `character_name: String = ""`

The name of the character this marker points to.

### Methods

#### `static func all() -> Array[DialogueMarker2D]`

Get all `DialogueMarker2D` nodes in the current scene tree.

#### `static func find_for_character(target_character_name: String) -> DialogueMarker2D`

Find a marker in the current scene tree that has a given character name.

#### `func get_position_in_viewport() -> Vector2`

Get the marker's position relative to the viewport.

## `DialogueStateContext`

Use these in scenes where you want to make a given node available to dialogue whenever it exists in the running scene tree.

### Properties

#### `alias: String = ""`

The name used in dialogue to refer to the exposed target node.

#### `target: Node`

The target who's values are exposed to dialogue.

## `DialogueResponsesMenu`

Use this in your custom balloon for a simple dialogue responses menu for when dialogue has responses to choose from. The example dialogue balloon already uses it.

### Signals

#### `response_focused(response: Variant)`

Emitted when a response is focused.

#### `signal response_selected(response: Variant)`

Emitted when a response is selected.

### Properties

#### `response_template: Control`

Optionally specify a control to duplicate for each response.

#### `next_action: StringName = &""`

The action for accepting a response (is possibly overridden by parent dialogue balloon).

#### `auto_configure_focus: bool = true`

Automatically set up focus neighbours when the responses list changes.

#### `auto_focus_first_item: bool = true`

Automatically focus the first item when showing.

#### `hide_failed_responses: bool = false`

Hide any responses where a response's `is_allowed` is false.

#### `responses: Array = []`

The list of dialogue responses.

### Methods

#### `func get_menu_items() -> Array`

Get the selectable items in the menu.

#### `func configure_focus() -> void`

Prepare the menu for keyboard and mouse navigation.

## `DialogueLabel`

Use this in your custom balloon to display the dialogue text. It handles typing out the text, pauses, speeds, inline mutations, etc.

> [!NOTE]
> The Dialogue Label can also be instanced to get some default properties preconfigured.

### Properties

#### `seconds_per_step: float = 0.02`

the speed at which the text types out.

#### `pause_at_characters: String = ".?!"`

automatically have a brief pause when these characters are encountered.

#### `skip_pause_at_character_if_followed_by: String = ")\""`

ignore automatic pausing if the pause character is followed by one of these.

#### `skip_pause_at_abbreviations: Array = ["Mr", "Mrs", "Ms", "Dr", "etc", "ex"]`

don't auto pause after these abbreviations (only if "." is in `pause_at_characters`).

#### `seconds_per_pause_step: float = 0.3`

the amount of time to pause when exposing a character present in pause_at_characters.

### Signals

#### `spoke(letter: String, letter_index: int, speed: float)`

emitted each step while typing out.

#### `started_typing()`

emitted when the label starts typing.

#### `skipped_typing()`

emitted when the player skips the label typing out.

#### `finished_typing()`

emitted when the label finishes typing.

### Methods

#### `func type_out() -> void`

Starts typing out the text of the label.

#### `func skip_typing() -> void`

Stop typing out the text and jump right to the end. This will emit `skipped_typing`.

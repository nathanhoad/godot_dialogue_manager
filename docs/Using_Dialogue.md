# Using dialogue in your game

It's up to you to implement the actual dialogue rendering and input control but there is an [example balloon](Example_Balloon.md) included to help get you started. You can also have a look at [these further examples](https://github.com/nathanhoad/example_dialogue_balloons).

## Getting a line of dialogue

A global called `DialogueManager` is available to provide lines of dialogue.

If you haven't specified your game states in [the editor](Settings.md) you can manually set them with something like:

```gdscript
# Game state objects are globals that have properties and methods used by your dialogue
DialogueManager.game_states = [GameState, SessionState]
```

Then you can get a line of dialogue by yielding to `get_next_dialogue_line` and providing a node title.

So, assuming your dialogue file was `res://assets/dialogue/example.tres` and you had a node title in there of `~ some_node_title` then you could do this to get the first printable dialogue:

```gdscript
var dialogue_resource = preload("res://assets/dialogue/example.tres")
var dialogue_line = yield(DialogueManager.get_next_dialogue_line("some_node_title", dialogue_resource), "completed")
```

You can also call `get_next_dialogue_line` on a resource directly (which is just a shortcut to calling the global):

```gdscript
var dialogue_resource = preload("res://assets/dialogue/example.tres")
var dialogue_line = yield(dialogue_resource.get_next_dialogue_line("some_node_title"), "completed")
```

This will find the line with the given title and then begin checking conditions and stepping over each line in the `next_id` sequence until we hit a line of dialogue that can be displayed (or the end of the conversation). Any mutations found along the way will be executed as well.

You need to `yield` this call because it can't guarantee an immediate return. If there are any mutations it will need to allow for them to run before finding the next line.

The returned line in dialogue is a `DialogueLine` and will have the following properties:

- **character**: String - The name of the character if there was one
- **dialogue**: String - The line of dialogue
- **translation_key**: String - The [static translation key](Writing_Dialogue.md#translations) (or the dialogue if no key was specified)
- **replacements**: Array of { expression, value_in_text } Dictionaries (expression is in AST format and can be manually resolved with `DialogueManager.replace_values()`)
- **pauses**: Dictionary of { index => time }
- **speeds**: Array of [index, speed]
- **inline_mutations**: Array of [index, expression] (expression is in AST format and which can be manually resolved with `DialogueManager.mutate()`)
- **next_id**: String - The next value to give to `get_next_dialogue_line()`
- **time**: null or String ("auto" or a float-like string)
- **responses**: Array of DialogueResponse:
  - **character**: String - The name of the character if there is one
  - **character_replacements**: Array of { expression, value_in_text } Dictionaries (expression is in AST format and can be manually resolved with `DialogueManager.replace_values()`)
  - **prompt**: String - The text to show a player
  - **is_allowed**: bool - false if this response has failed its condition check
  - **replacements**: Array of { expression, value_in_text } Dictionaries (expression is in AST format and can be manually resolved with `DialogueManager.replace_values()`)
  - **translation_key**: String - The [static translation key](Writing_Dialogue.md#translations) (or the dialogue if no key was specified)
  - **next_id**: String - The next value to give to `get_next_dialogue_line()` if the player chooses this response

Now that you have a line of dialogue you can use a `DialogueLabel` node to show it.

## DialogueLabel node

The addon provides a `DialogueLabel` node (an extension of the RichTextLabel node) which helps with rendering a line of dialogue text. 

This node is given a `DialogueLine` object (mentioned above) and uses its properties to work out how to handling typing out the dialogue. It will automatically handle any `bb_code`, `wait`, `speed`, and `inline_mutation` references.

Use `type_out()` to start typing out the text. The label will emit a `finished` signal when it has finished typing.

The label will emit a `paused` signal (along with the duration of the pause) when there is a pause in the typing and a `spoke` signal (along with the letter typed and the current speed) when a letter was just typed.

## Conditions

Conditions let you optionally show dialogue or response options.

If you have a condition in the dialogue editor like `if some_variable == 1` or `if some_other_variable` then you need to have a matching property on one of the given `game_state`s or the current scene.

If you have a condition like `if has_item("rubber_chicken")` then you will need a method on one of the `game_state`s or the current scene that matches the signature `func has_item(thing: String) -> bool:` (where the argument `thing` can be called whatever you want, as long as the type matches or is untyped). The method will be given `"rubber_chicken"` as that argument).

## Mutations

Mutations are for updating game state or running sequences (or both).

If you have a mutation in the dialogue editor like `do some_variable = 1` then you will need a matching property on one of your `game_state`s or the current scene.

If you have a mutation like `do animate("Character", "cheer")` then you will need a method on one of the `game_state`s or the current scene that matches the signature `func animate(character: String, animation: String) -> void:`. The argument `character` will be given `"Character"` and `animation` will be given `"cheer"`.

## Signals

When the Dialogue Manager first returns a line of dialogue it will emit a `dialogue_started` signal. When it encounters the end of a sequence of dialogue it will emit a `dialogue_finished` signal.


## Generating Dialogue Resources at runtime

If you need to construct a `DialogueResource` at runtime you can use `get_resource_from_text(string)`:

```gdscript
var resource = DialogueManager.get_resource_from_text("~ title\nCharacter: Hello!)
```

This will run the given text through the parser.

If there were syntax errors they will be listed under `resource.errors`.

If there were no errors then you can use this ephemeral resource like normal:

```gdscript
var dialogue = yield(DialogueManager.get_next_dialogue_line("title", resource), "completed")
```
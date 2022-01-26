![Dialogue Manager for Godot](docs/hero.png)

A stateless branching dialogue manager for the [Godot Game Engine](https://godotengine.org/). 

Write your dialogue in a simple script-like way and run it in your game.

## Installation

1. Clone or download a copy of this repository.
2. Copy the contents of `addons/dialogue_manager` into your `res://addons/dialogue_manager` directory.
3. Enable `Dialogue Manager` in your project plugins.

## Writing Dialogue

Navigate to the "Dialogue" tab in the editor.

![Dialogue tab](docs/dialogue-tab.jpg)

Open some dialogue by clicking the "new dialogue file" button or "open dialogue" button.

![New and Open buttons](docs/new-open-buttons.jpg)


### Nodes

All dialogue exists within nodes. A node is started with a line beginning with a "#".

![Node titles begin with a "#"](docs/node-title.jpg)

A node will continue until another title is encountered or the end of the file.


### Dialogue

A dialogue line is either just text or in the form of "Character: What they say". Dialogue lines can contain variables wrapped in "{{}}". Any variables you use must be a property or method on one of your provided game states (see down below under **Settings, Runtime**).

![Dialogue lines](docs/dialogue-lines.jpg)

To give the player branching options you can start a line with "- " and then a prompt.

![Empty prompts](docs/empty-prompts.jpg)

By default responses will just continue on to the lines below the list when one is chosen.

To branch, you can provide and indented body under a given prompt or add a `goto # Some title` where "Some title" is the title of another node. If you want to end the conversation right away you can `goto # END`.

![Prompts](docs/prompts.jpg)


### Conditions

You can use conditional blocks to further branch. Start a condition line with "if" and then a comparison. You can compare variables or function results.

Additional conditions use "elif" and you can use "else" to catch any other cases.

![Conditional lines](docs/conditions.jpg)

Responses can also have conditions. Wrap these in "[" and "]".

![Conditional responses](docs/conditional-responses.jpg)

If using a condition and a goto on a response line then make sure the goto is provided last.

### Mutations

You can modify state with either a "set" or a "do" line. Any variables or functions used must be a property or method on one of your provided game states (see down below under **Settings, Runtime**).

![Mutations](docs/mutations.jpg)

In the example above, the dialogue manager would expect one of yoru game states to implement a method with the signature `func animate(string, string) -> void`

### Error checking

Running an error check should highlight any syntax or referential integrity issues with your dialogue.

![Errors](docs/errors.jpg)

If a dialogue resource has any errors on it at runtime it will throw an assertian failure and tell you which file it is.


### Running a test scene

For dialogue that doesn't rely too heavily on game state conditions you can do a quick test of it by clicking the "Run the test scene" button in the main toolbar.

This will boot up a test scene and run the currently active node. Use `ui_up`, `ui_down`, and `ui_accept` to navigate the dialogue and responses.

Once the conversation is over the scene will close.


### Translations

You can export tranlsations as CSV from the "Translations" menu. This will find any unique dialogue lines or response prompts and add them to a list. If a static key is specified for the line (eg. [TR:SOME_KEY]) then that will be used as the translation key, otherwise the dialogue/prompt itself will be.

If the target CSV file already exists, it will be merged with.


## Settings

### Editor
- `Check for errors as you type` will do a syntax check after 1 second of inactivity
- `Treat missing translations as errors` can be enabled if you are using static translation keys and are adding them manually (there is an automatic static key button but you might be writing specific keys)

### Runtime

The dialogue runtime itself is stateless, meaning it looks to your game to provide values for variables and for methods to run. At run time, the dialogue manager will check the current scene first and then check any global states provided here.

For example, I have a persistent `GameState` and an ephemeral `SessionState` that my dialogue uses.

![GameState and SessionState are used by dialogue](docs/states.jpg)

## Using dialogue in your game

A global called `DialogueManager` is available to provide lines of dialogue.

If you haven't specified your game states mentioned above you can manually set them with something like:

```gdscript
# Game state objects are globals that have properties and methods used by your dialogue
DialogueManager.game_states = [GameState, SessionState]
```

Then you can get a line of dialogue by yielding to `get_next_dialogue_line` and providing a node title.

So, assuming your dialogue file was `res://assets/dialogue/example.tres` and you had a node title in there of `# Some node title` then you could do this to get the first printable dialogue:

```gdscript
var dialogue_resource = preload("res://assets/dialogue/example.tres")
var dialogue = yield(DialogueManager.get_next_dialogue_line("Some node title", dialogue_resource), "completed")
```

This will find the line with the given title and then begin checking conditions and stepping over each line in the `next_id` sequence until we hit a line of dialogue that can be displayed (or the end of the conversation). Any mutations found along the way will be exectued as well.

The returned line in `dialogue` will have the following properties:

- **character**: String
- **dialogue**: String
- **next_id**: String
- **responses**: Array of DialogueOptions:
  - **prompt**: String
  - **next_id**: String

It's up to you to implement the actual dialogue rendering and input control.

There is an example implementation of a dialogue balloon you can use to get started.

```gdscript
var dialogue_resource = preload("res://assets/dialogue/example.tres")
DialogueManager.show_example_dialogue_balloon("Some title", dialogue_resource)
```

This will add a CanvasLayer and some UI to the bottom of the screen for an interactive dialogue balloon. Input is mapped to `ui_up`, `ui_down`, and `ui_accept`.

![Example balloon instance](docs/example-balloon.jpg)

Once you have your own balloon scene you can do something like this (This is what I have in my game):

```gdscript
# Start some dialogue from a title
func show_dialogue(title: String, resource: DialogueResource) -> void:
	var dialogue = yield(DialogueManager.get_next_dialogue_line(title, resource), "completed")
	if dialogue != null:
		var balloon := DialogueBalloon.instance()
		balloon.dialogue = dialogue
		add_child(balloon)
		# Dialogue might have response options so we have to wait and see
		# what the player chose
		show_dialogue(yield(balloon, "dialogue_actioned"), resource)
```

![Real dialogue balloon example](docs/real-example.jpg)


### Conditions

Conditions let you optionally show dialogue or response options.

If you have a condition in the dialogue editor like `if some_variable == 1` or `if some_other_variable` then you need to have a matching property on one of the given `game_state`s or the current scene.

If you have a condition like `if has_item("rubber_chicken")` then you will need a method on one of the `game_state`s or the current scene that matches the signature `func has_item(thing: String) -> bool:` (where the argument `thing` can be called whatever you want, as long as the type matches or is untyped). The method will be given `"rubber_chicken"` as that argument).

### Mutations

Mutations are for updating game state or running sequences (or both).

If you have a mutation in the dialogue editor like `do some_variable = 1` then you will need a matching property on one of your `game_state`s or the current scene.

If you have a mutation like `do animate("Character", "cheer")` then you will need a method on one of the `game_state`s or the current scene that matches the signature `func animate(character: String, animation: String) -> void:`. The argument `character` will be given `"Character"` and `animation` will be given `"cheer"`.

## Translations

By default, all dialogue and response prompts will be run through Godot's `tr` function to provide translations. 

You can turn this off by setting `DialogueManager.auto_translate = false` but beware, if it is off you may need to handle your own variable replacements if using manual translation keys. You can use `DialogueManager.replace_values(line)` or `DialogueManager.replace_values(response)` to replace text variable markers with their values.

This might be useful for cases where you have audio dialogue files that match up with lines.

## Contributors

[Nathan Hoad](https://nathanhoad.net)

## License

Licensed under the MIT license, see `LICENSE` for more information.

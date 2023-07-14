# Using dialogue in your game

It's up to you to implement the actual dialogue rendering and input control but there are [a few example balloons](Example_Balloons.md) included to get you started.

To use the built-in example balloon you can call [`DialogueManager.show_example_dialogue_balloon(resource, title)`](API.md) with a dialogue resource and the title you want to start from.

Once you get to the stage of building your own balloon you'll need to know how to get a line of dialogue and how to use the dialogue label node.

## Getting a line of dialogue

A global called `DialogueManager` is available to provide lines of dialogue.

To request a line, call `await DialogueManager.get_next_dialogue_line(resource, title)` with a dialogue resource (\*.dialogue file) and a starting title (you can also call `get_next_dialogue_line` on the resource directly, see below). This will traverse each line (running mutations along the way) and returning the first printable line of dialogue.

For example, if you have some dialogue like:

```
~ start

Nathan: Hi! I'm Nathan.
Nathan: Here are some options.
- First one
	Nathan: You picked the first one.
- Second one
	Nathan: You picked the second one.
```

And then in your game:

```gdscript
var resource = load("res://some_dialogue.dialogue")
# then
var dialogue_line = await DialogueManager.get_next_dialogue_line(resource, "start")
# or
var dialogue_line = await resource.get_next_dialogue_line("start")
```

Then `dialogue_line` would now hold a `DialogueLine` containing information for the line `Nathan: Hi! I'm Nathan`.

To get the next line of dialogue you can call `get_next_dialogue_line` again with `dialogue_line.next_id` as the title:

```
dialogue_line = await DialogueManager.get_next_dialogue_line(resource, dialogue_line.next_id)
# or
dialogue_line = await resource.get_next_dialogue_line(dialogue_line.next_id)
```

Now `dialogue_line` holds a `DialogueLine` containing the information for the line `Nathan: Here are some options.`. This object also contains the list of response options.

Each option also contains a `next_id` property that can be used to continue along that branch.

For more information about `DialogueLine`s see the [API documentation](API.md).

## DialogueLabel node

The addon provides a `DialogueLabel` node (an extension of the RichTextLabel node) which helps with rendering a line of dialogue text.

This node is given a `dialogue_line` (mentioned above) and uses its properties to work out how to handling typing out the dialogue. It will automatically handle any `bb_code`, `wait`, `speed`, and `inline_mutation` references.

Use `type_out()` to start typing out the text. The label will emit a `finished_typing` signal when it has finished typing.

The label will emit a `paused_typing` signal (along with the duration of the pause) when there is a pause in the typing and a `spoke` signal (along with the letter typed and the current speed) when a letter was just typed.

The `DialogueLabel` typing speed can be configured in your balloon by changing the `seconds_per_step` property. It will also automatically wait for a brief time when it encounters characters specified in the `pause_at_characters` property (by default, just ".").

## Generating Dialogue Resources at runtime

If you need to construct a dialogue resource at runtime you can use `create_resource_from_text(string)`:

```gdscript
var resource = DialogueManager.create_resource_from_text("~ title\nCharacter: Hello!")
```

This will run the given text through the parser.

If there were syntax errors the method will fail.

If there were no errors then you can use this ephemeral resource like normal:

```gdscript
var dialogue_line = await DialogueManager.get_next_dialogue_line("title", resource)
```

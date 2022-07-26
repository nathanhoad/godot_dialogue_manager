# Example balloon

There is an example implementation of a dialogue balloon you can use to get started (it's the same balloon that gets used when you run the test scene from the dialogue editor).

Have a look at [/addons/dialogue_manager/example_balloon](../addons/dialogue_manager/example_balloon) to see how it's put together.

You can give the balloon a go in your game by doing something like this:

```gdscript
var dialogue_resource = preload("res://assets/dialogue/example.tres")
DialogueManager.show_example_dialogue_balloon("Some title", dialogue_resource)
```

This will add a CanvasLayer and some UI to the bottom of the screen for an interactive dialogue balloon. Input is mapped to `ui_up`, `ui_down`, and `ui_accept`, as well as mouse clicks.

![Example balloon instance](example-balloon.jpg)

Make a copy of the example balloon directory to start customising it to fit your own game.

Once you have your own balloon scene you can do something like this (I have something similar in my game):

```gdscript
# Start some dialogue from a title, then recursively step through further lines
func show_dialogue(title: String, resource: DialogueResource) -> void:
	var dialogue = yield(resource.get_next_dialogue_line(title), "completed")
	if dialogue != null:
		var balloon := DialogueBalloon.instance()
		balloon.dialogue = dialogue
		add_child(balloon)
		# Dialogue might have response options so we have to wait and see
		# what the player chose. "actioned" is emitted and passes the "next_id"
		# once the player has made their choice.
		show_dialogue(yield(balloon, "actioned"), resource)
```

![Real dialogue balloon example](real-example.jpg)

To achieve something similar to the above example (balloons that position themselves near characters) I'd suggest parenting your balloon control to a `Node2D` that you can then move to the character's `global_position`. Additionally, within each "talkable" character I have a `Position2D` node that is used to work out where the pin should be located.

For more example balloons, check out [github.com/nathanhoad/example_dialogue_balloons](https://github.com/nathanhoad/example_dialogue_balloons)
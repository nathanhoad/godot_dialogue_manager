# Basic Dialogue

Navigate to the "Dialogue" tab in the editor.

![Dialogue tab](media/dialogue-tab.jpg)

Open some dialogue by clicking the "new dialogue file" button or "open dialogue" button.

![New and Open buttons](media/new-open-buttons.jpg)

The most basic dialogue is just a string:

```
This is some dialogue.
```

If you want to add a character that's doing the talking then include a name before a colon and then the dialogue:

```
Nathan: This is me talking.
```

You can add some spice to your dialogue with [BBCode](https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html#reference). Along with everything available to Godot's `RichTextLabel` you can also use a few extra ones provided by Dialogue Manager:

- `[wait=N]` where N is the number of seconds to pause typing of dialogue.
- `[speed=N]` where N is a number to multiply the default typing speed by.

Lines of dialogue are written one after another:

```
Nathan: I'll say this first.
Nathan: Then I'll say this line.
```

To add some interactivity to the dialogue you can specify responses. Responses are lines that begin with a `- `:

```
- This is a response
- This is a different response
- And this is the last one
```

## Responses

One way of branching the dialogue after a response is to nest some more dialogue below each response. Nested response dialogue can nest indefinitely as more and more branches get added

```
Nathan: How many projects have you started and not finished?
- Just a couple
	Nathan: That's not so bad.
- A lot
	Nathan: Maybe you should finish one before starting another one.
- I always finish my projects
	Nathan: That's great!
	Nathan: ...but how many is that?
	- A few
		Nathan: That's great!
	- I haven't actually started any
		Nathan: That's what I thought.
```

## Randomising lines of dialogue

If you want to pick a random line out of multiple, you can mark the lines with a `%` at the start like this:

```
Nathan: I will say this.
% Nathan: And then I might say this
% Nathan: Or maybe this
% Nathan: Or even this?
```

Each line will have an equal chance of being said.

To weight lines, use a `%` followed by a number to weight by. For example, a `%2` will mean that line has twice the chance of being picked as a normal line.

```
%3 Nathan: This line has a 60% chance of being picked
%2 Nathan: This line has a 40% chance of being picked
```

To separate multiple groups of random lines, use an empty line:

```
% Group 1
% Also group 1

% Group 2
% And this is also group 2
```

You can also have whole blocks be random:

```
%
	Nathan: This is the first block.
	Nathan: Still the first block.
%
	Nathan: This is the second block.
```

If the first random item is chosen it will play through both nested lines.

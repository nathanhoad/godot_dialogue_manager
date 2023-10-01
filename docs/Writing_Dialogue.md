# Writing Dialogue

Navigate to the "Dialogue" tab in the editor.

![Dialogue tab](dialogue-tab.jpg)

Open some dialogue by clicking the "new dialogue file" button or "open dialogue" button.

![New and Open buttons](new-open-buttons.jpg)

Dialogue generally begins with a title. A title line begins with a "~ " followed by lower-case words with underscores and no spaces.

```
~ talk_to_nathan
```

You can have any number of titles in a dialogue file. They are generally used to break up chunks of dialogue and are handy starting points when [using dialogue in your game](./Using_Dialogue.md).

Titles can also be thought of as markers within the dialogue.

Dialogue will run until it hits an `=> END`, `=> END!`, or the end of the file.

## Dialogue

A dialogue line is either just text or in the form of "Character: What they say".

You can add a bit of random variation with text surrounded by `[[]]`. For example, `Nathan: [[Hi|Hello|Howdy]]! I'm Nathan` would pick one from "Hi", "Hello", or "Howdy".

Dialogue lines can contain **variables** wrapped in "{{}}" (in either the character name or the dialogue). Any variables referenced must be either globals or specified in the Dialogue Manager settings.

```
This is a line said by nobody.
Nathan: I am saying this line.
Nathan: The value of some_variable is {{SomeGlobal.some_property}}.
```

To break a single line into multiple lines for display, you can either use a newline (`\n`) or indent each line below the first line. For example, these two snippets would be equivalent:

```
Coco: This is the first line.
	This line would show up below it in the same balloon.
	And even this line.
```

and

```
Coco: This is the first line.\nThis line would show up below it in the same balloon.\nAnd even this line.
```

_Note: When using indented line breaks and [line IDs for translations](./Translations.md) you can only specify a line ID on the first (unindented) line of each group._

### Escaping characters

Escaping characters in dialogue can be done by using a backslash. This is relevant if your dialogue includes characters utilized in the syntax of the dialogue system, such as the colon (":").

To display a colon in your dialogue, use a backslash ("\\") before it.

```dialogue
Character : This is how\: you escape a colon.
```

### Markup

Dialogue lines can also contain **bb_code** for RichTextEffects (if you end up using a `RichTextLabel` or the `DialogueLabel` provided by this addon).

If you use the `DialogueLabel` node then you can also make use of the `[wait=N]` and `[speed=N]` codes. `wait` will pause the typing of the dialogue for `N` seconds (eg. `[wait=1.5]` will pause for 1.5 seconds). `speed` will change the typing speed of the current line of dialogue by that factor (eg `[speed=10]` will change the typing speed to be 10 times faster than normal).

There is also a `[next]` code that you can use to signify that a line should be auto advanced. If given no arguments it will auto advance immediately after the text has typed out. If given something like `[next=0.5]` it will wait for 0.5s after typing has finished before moving to the next line. If given `[next=auto]` it will wait for an automatic amount of time based on the length of the line.

### Tags

If you need to annotate your lines with tags then you can wrap them in `[#` and `]`, separated by commas. So to specify "happy" and "surprised" tags for a line you would do something like:

```
Nathan: [#happy, #surprised] Oh, Hello!
```

### Randomising lines of dialogue

If you want to pick one from a few lines of dialogue you can mark the line with a `%` at the start like this:

```
Nathan: I will say this.
% Nathan: And then I might say this
% Nathan: Or maybe this
% Nathan: Or even this?
```

Each line will have an equal chance of being said.

To weight lines use a `%` followed by a number to weight by. For example a `%2` will mean that line has twice the chance of being picked as a normal line.

```
%3 Nathan: This line as a 60% chance of being picked
%2 Nathan: This line has an 40% chance of being picked
```

## Jumps

If you want to redirect flow to another title then you can use a jump line. Assuming the target title is "another_title" your jump line would be

```
=> another_title
```

If you wanted the dialogue manager to jump to that title but then return to this line when it is finished then you can write the goto line as:

```
=>< another_title
```

You can write what are effectively "snippets" of dialogue this way.

You can also import titles from other files. Specify your imports at the top of the file like this:

```
import "res://snippets.dialogue" as snippets
```

And then you can jump to titles by prefixing them with `snippets/`. For example, say there was a "talk_to_nathan" title in the snippets file then in the current file I could use `=> snippets/talk_to_nathan`.

## Responses

To give the player branching options you can start a line with "- " and then a prompt. Like dialogue, prompts can also contain variables wrapped in `{{}}`.

```
Nathan: What would you like?
- This one
- No, this one
- Nothing
```

By default responses will just continue on to the lines below the list when one is chosen.

To branch, you can provide and indented body under a given prompt or add a `=> another_title` where "another_title" is the title of another node. If you want to end the conversation right away you can `=> END`.

```
Nathan: What would you like?
- This one
    Nathan: Ah, so you want this one?
- Another one => another_title
- Nothing => END
```

If a response prompt contains a character name then it will be treated as an actual line of dialogue when the player selects it.

For example:

```
Someone: Here is a thing you can do.
- That's good to hear!
    Nathan: That's good to hear!
- That's definitely news
    Nathan: That's definitely news
```

...is the same as writing:

```
Someone: Here is a thing you can do
- Nathan: That's good to hear!
- Nathan: That's definitely news
```

## Conditions

You can use conditional blocks to further branch. Start a condition line with "if" and then a comparison. You can compare variables or function results.

Additional conditions use "elif" and you can use "else" to catch any other cases.

```
if SomeGlobal.some_property >= 10
    Nathan: That property is greater than or equal to 10
elif SomeGlobal.some_other_property == "some value"
    Nathan: Or we might be in here.
else
    Nathan: If neither are true I'll say this.
```

You can also start a conditional block with "while". These blocks will loop as long as the condition is true.

```
while SomeGlobal.some_property < 10
    Nathan: The property is still less than 10 - specifically, it is {{SomeGlobal.some_property}}.
    do SomeGlobal.some_property += 1
Nathan: Now, we can move on.
```

Responses can also have "if" conditions. Wrap these in "[" and "]".

```
Nathan: What would you like?
- This one [if SomeGlobal.some_property == 0 or SomeGlobal.some_other_property == false]
    Nathan: Ah, so you want this one?
- Another one [if SomeGlobal.some_method()] => another_title
- Nothing => END
```

If using a condition and a goto on a response line then make sure the goto is provided last.

Conditions can also be used inline in a dialogue line when wrapped with "[if predicate]" and "[/if]".

```
Nathan: I have done this [if already_done]once again[/if]
```

## Mutations

You can modify state with either a "set" or a "do" line.

```
if SomeGlobal.has_met_nathan == false
    do SomeGlobal.animate("Nathan", "Wave")
    Nathan: Hi, I'm Nathan.
    set SomeGlobal.has_met_nathan = true
Nathan: What can I do for you?
- Tell me more about this dialogue editor
```

In the example above, the dialogue manager would expect a global called `SomeGlobal` to implement a method with the signature `func animate(string, string) -> void`.

You can pass an array of nodes/objects when [requesting a line of dialogue](API.md#func-get_next_dialogue_lineresource-resource-key-string--0-extra_game_states-array-----dictionary) which will also be checked for possible mutation methods.

There are also a couple of special built-in mutations you can use:

- `emit(...)` - emit a signal on a game state or the current scene.
- `wait(float)` - wait for `float` seconds (this has no effect when used inline).
- `debug(...)` - print something to the Output window.

Mutations can also be used inline. Inline mutations will be called as the typed out dialogue reaches that point in the text.

```
Nathan: I'm not sure we've met before [do wave()]I'm Nathan.
Nathan: I can also emit signals[do emit("some_signal")] inline.
```

One thing to note is that _inline mutations_ that use `await` won't be awaited so the dialogue will continue right away.

### State shortcuts

If you want to shorten your references to state from something like `SomeGlobal.some_property` to just `some_property` then you can set up global state shortcuts in [Settings](./Settings.md).

## Error checking

Your dialogue will be periodically checked for syntax or referential integrity issues.

If any are found they will be highlighted and must be fixed before you can run your game.

## Running a test scene

For dialogue that doesn't rely too heavily on game state conditions you can do a quick test of it by clicking the "Run the test scene" button in the main toolbar.

This will boot up a test scene and run from the nearest title marker above the cursor position. Use your mouse and/or `ui_up`, `ui_down`, and `ui_accept` to navigate the dialogue and responses.

Once the conversation is over the scene will close.

### Custom test scene

You can override which scene is run when clicking the test button in settings.

Your custom test scene must extend `BaseDialogueTestScene` which will provide you with a `resource` property (which is the `DialogueResource` currently open) and the `title` to start from.

The simplest example custom test scene is something like this (which is pretty much the same as the actual test scene):

```gdscript
extends BaseDialogueTestScene

func _ready() -> void:
    # Change this to open your custom balloon
	DialogueManager.show_example_dialogue_balloon(resource, title)
```

## Translations

You can export translations as CSV from the "Translations" menu in the dialogue editor.

This will find any unique dialogue lines or response prompts and add them to a list. If an ID is specified for the line (eg. `[ID:SOME_KEY]`) then that will be used as the translation key, otherwise the dialogue/prompt itself will be.

If the target CSV file already exists, it will be merged with.

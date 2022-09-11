# Writing Dialogue

Navigate to the "Dialogue" tab in the editor.

![Dialogue tab](dialogue-tab.jpg)

Open some dialogue by clicking the "new dialogue file" button or "open dialogue" button.

![New and Open buttons](new-open-buttons.jpg)

## Nodes

All dialogue exists within nodes. A node is started with a line beginning with a "~ ".

```
~ talk_to_nathan
```

A node will continue until another title is encountered or the end of the file.

## Dialogue

A dialogue line is either just text or in the form of "Character: What they say". 

You can add a bit of random variation with text surrounded by `[[]]`. For example, `Nathan: [[Hi|Hello|Howdy]]! I'm Nathan` would pick one from "Hi", "Hello", or "Howdy".

Dialogue lines can contain **variables** wrapped in "{{}}" (in either the character name or the dialogue). Any variables you use must be a property or method on one of your provided game states (see down below under **Settings, Runtime**).

```
This is a line said by nobody.
Nathan: I am saying this line.
Nathan: The value of some_variable is {{some_variable}}.
```

Dialogue lines can also contain **bb_code** for RichTextEffects (if you end up using a `RichTextLabel` or the `DialogueLabel` provided by this addon).

If you use the `DialogueLabel` node then you can also make use of the `[wait=N]` and `[speed=N]` codes. `wait` will pause the typing of the dialogue for `N` seconds (eg. `[wait=1.5]` will pause for 1.5 seconds). `speed` will change the typing speed of the current line of dialogue by that factor (eg `[speed=10]` will change the typing speed to be 10 times faster than normal).

There is also a `[next]` code that you can use to signify that a line should be auto advanced. If given no arguments it will auto advance immediately after the text has typed out. If given something like `[next=0.5]` it will wait for 0.5s after typing has finished before moving to the next line. If given `[next=auto]` it will wait for an automatic amount of time based on the length of the line.

### Randomising lines of dialogue

If you want to pick one from a few lines of dialogue you can mark the line witha `%` at the start like this:

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

## Gotos

If you want to jump to another title then you can use a goto line. Assuming the target title is "another_title" your goto line would be 

```
=> another_title
```

If you wanted the dialogue manager to jump to that title but then return to this line when it is finished then you can write the goto line as:

```
=>< another_title
```

You can write what are effectively "snippets" of dialogue this way.

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
if some_variable >= 10
    Nathan: That variable is greather than or equal to 10
elif something_else == "some value"
    Nathan: Or we might be in here.
else
    Nathan: If neither are true I'll say this.
```

Responses can also have conditions. Wrap these in "[" and "]".

```
Nathan: What would you like?
- This one [if some_variable == 0 or some_other_variable == false]
    Nathan: Ah, so you want this one?
- Another one [if some_function()] => another_title
- Nothing => END
```


If using a condition and a goto on a response line then make sure the goto is provided last.

## Mutations

You can modify state with either a "set" or a "do" line. Any variables or functions used must be a property or method on one of your provided game states (see down below under **Settings, Runtime**).

```
if has_met_nathan == false
    do animate("Nathan", "Wave")
    Nathan: Hi, I'm Nathan.
    set has_met_nathan = true
Nathan: What can I do for you?
- Tell me more about this dialogue editor
```

In the example above, the dialogue manager would expect one of your game states to implement a method with the signature `func animate(string, string) -> void`.

There are also a couple of special built-in mutations you can use:

- `emit(...)` - emit a signal on your game states.
- `wait(float)` - wait for `float` seconds (this has no effect when used inline).
- `debug(...)` - print something to the Output window.

Mutations can also be used inline. Inline mutations will be called as the typed out dialogue reaches that point in the text.

```
Nathan: I'm not sure we've met before [do wave()]I'm Nathan.
Nathan: I can also emit signals[do emit("some_signal")] inline.
```

One thing to note is that inline mutations that use `yield` won't be awaited so the dialogue will continue right away.

## Error checking

Running an error check should highlight any syntax or referential integrity issues with your dialogue.

![Errors](errors.jpg)

If a dialogue resource has any errors on it at runtime it will throw an assertion failure and tell you which file it is.

## Running a test scene

For dialogue that doesn't rely too heavily on game state conditions you can do a quick test of it by clicking the "Run the test scene" button in the main toolbar.

This will boot up a test scene and run the currently active node. Use `ui_up`, `ui_down`, and `ui_accept` to navigate the dialogue and responses.

Once the conversation is over the scene will close.

## Translations

You can export tranlsations as CSV from the "Translations" menu in the dialogue editor. 

This will find any unique dialogue lines or response prompts and add them to a list. If a static key is specified for the line (eg. `[TR:SOME_KEY]`) then that will be used as the translation key, otherwise the dialogue/prompt itself will be.

If the target CSV file already exists, it will be merged with.
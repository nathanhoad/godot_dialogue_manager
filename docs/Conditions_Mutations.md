# Conditions & Mutations

## Conditions

### If/else

You can use conditional blocks to further branch your dialogue. Start a condition line with "if" and then provide an expression. You can compare variables or function results.

Additional conditions use "elif" and you can use "else" to catch any other cases.

```
if SomeGlobal.some_property >= 10
    Nathan: That property is greater than or equal to 10
elif SomeGlobal.some_other_property == "some value"
    Nathan: Or we might be in here.
else
    Nathan: If neither are true, I'll say this.
```

_Note: To escape a condition line (i.e. if you wanted to start a dialogue line with "if"), you can prefix the condition keyword with a "\"._

Responses can also have "if" conditions. Wrap these in "[" and "]".

```
Nathan: What would you like?
- This one [if SomeGlobal.some_property == 0 or SomeGlobal.some_other_property == false]
    Nathan: Ah, so you want this one?
- Another one [if SomeGlobal.some_method()] => another_title
- Nothing => END
```

If using a condition and a goto on a response line, make sure the goto is provided last.

Conditions can also be used inline in a dialogue line when wrapped with "[if predicate]" and "[/if]".

```
Nathan: I have done this [if already_done]once again[/if]
```

For simple this-or-that conditions, you can write them like this:

```
Nathan: You have {{num_apples}} [if num_apples == 1]apple[else]apples[/if], nice!
```

Randomised lines and randomised jump lines can also have conditions. Conditions for randomised lines go in square brackets after the `%` and before the line's content:

```
% => some_title
%2 => some_other_title
% [if SomeGlobal.some_condition] => another_title
```

### Match

To shortcut some if/elif/elif/elif chains you use a `match` line:

```
match SomeGlobal.some_property
    when 1
        Nathan: It is 1.
    when > 5
        Nathan: It is less than 5 (but not 1).
    else
        Nathan: It was something else.
```

### While

You can also start a conditional block with "while". These blocks will loop as long as the condition is true.

```
while SomeGlobal.some_property < 10
    Nathan: The property is still less than 10 - specifically, it is {{SomeGlobal.some_property}}.
    do SomeGlobal.some_property += 1
Nathan: Now, we can move on.
```

## Mutations

You can affect state with either a "set" or a "do" line.

```
if SomeGlobal.has_met_nathan == false
    do SomeGlobal.animate("Nathan", "Wave")
    Nathan: Hi, I'm Nathan.
    set SomeGlobal.has_met_nathan = true
Nathan: What can I do for you?
- Tell me more about this dialogue editor
```

In the example above, the dialogue manager would expect a global called `SomeGlobal` to implement a method with the signature `func animate(string, string) -> void`.

You can pass an array of nodes/objects as the `extra_game_states` parameter when [requesting a line of dialogue](API.md#func-get_next_dialogue_lineresource-resource-key-string--0-extra_game_states-array-----dictionary) which will also be checked for possible mutation methods.

Mutations can also be used inline. Inline mutations will be called as the typed out dialogue reaches that point in the text.

```
Nathan: I'm not sure we've met before [do wave()]I'm Nathan.
Nathan: I can also emit signals[do SomeGlobal.some_signal.emit()] inline.
```

Inline mutations that use `await` in their implementation will pause typing of dialogue until they resolve. To ignore awaiting, add a "!" after the "do" keyword - e.g. `[do! something()]`.

### Signals

Signals can be emitted similarly to how they are emitted in GDScript - by calling `emit` on them.

For example, if `SomeGlobal` has a signal called `some_signal` that has a single string parameter, you can emit it from dialogue like this:

```
do SomeGlobal.some_signal.emit("some argument")
```

### Null coalescing

In some cases you might want to refer to properties of an object that may or may not be defined. This is where you can make use of null coalescing:

```
if some_node_reference?.name == "SomeNode"
    Nathan: Notice the "?." syntax?
```

If `some_node_reference` is null then the whole left side of the comparison will be null and, therefore, not be equal to "SomeNode" and fail. If the null coalescing isn't used here and `some_node_reference` is null then the game will crash.

### State shortcuts

If you want to shorten your references to state from something like `SomeGlobal.some_property` to just `some_property`, there are two ways you can do this.

1. If you use the same state in all of your dialogue, you can set up global state shortcuts in [Settings](./Settings.md).
2. Or, if you want different shortcuts per dialogue file, you can add a `using SomeGlobal` clause (for whatever autoload you're using) at the top of your dialogue file.

## Special variables/mutations

There are a couple of special built-in mutations you can use:

- `do wait(float)` - wait for `float` seconds (this has no effect when used inline).
- `do debug(...)` - print something to the Output window.

There is also a special property `self` that you can use in dialogue to refer to the `DialogueResource` that is currently being run.

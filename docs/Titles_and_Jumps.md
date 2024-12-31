# Titles and Jumps

Titles are markers within your dialogue that you can start from and jump to. Usually, in your game you would start some dialogue by providing a title (the default title is `start` but it could be whatever you've written in your dialogue).

Titles start with a `~ ` and are named (without any spaces):

```
~ this_is_a_title
```

To jump to a title from somewhere in dialogue you can use a jump/goto line. Jump lines are prefixed with a `=> ` and then specify the title to go to.

```
=> this_is_a_title
```

When the dialogue runtime encounters a jump it will then direct the flow to that title marker and continue from there.

If you want to end the flow from within the dialogue you can jump to `END`:

```
=> END
```

This will end the current flow of dialogue.

You can also use a "jump and return" kind of jump that redirects the flow of dialogue and then returns to where it jumped from. Those lines are prefixed with `=>< ` and then specify the title to jump to. Once the flow encounters an `END` (or the end of the file) flow will return to where it jumped from and continue from there.

If you want to force the end of the conversation regardless of any chained "jump and returns", you can use an `=> END!` line.

Jumps can also be used inline for responses:

```
~ start
Nathan: Well?
- First one
- Another one => another_title
- Start again => start
=> END

~ another_title
Nathan: Another one?
=> END
```

## Expression Jumps

You can use expressions as jump directives. The expression needs to resolve to a known title name or results will be unexpected.

**Use these with caution** as the dialogue compiler can't verify expression values match any titles at compile time.

Expression jumps look something like:

`=> {{SomeGlobal.some_property}}`
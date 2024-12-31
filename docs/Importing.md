# Importing dialogue into other dialogue

If you have a dialogue file that contains common dialogue that you want to use in multiple other files you can `import` it into those files.

For example, we can have a `snippets.dialogue` file:

```
~ banter
Nathan: Blah blah blah.
=> END
```

Which we can then import into another dialogue file and jump to the `banter` title from the snippets file (note the `=><` syntax which denotes to return to this line after the jumped dialogue finishes):

```
import "res://snippets.dialogue" as snippets

~ start
Nathan: The next line will be from the snippets file:
=>< snippets/banter
Nathan: That was some banter!
=> END
```

# Tags

If you need to annotate your lines with tags, you can wrap them in `[#` and `]`, separated by commas. So to specify "happy" and "surprised" tags for a line, you would do something like:

```
Nathan: [#happy, #surprised] Oh, Hello!
```

At runtime, the `DialogueLine`'s `tags` property would include `["happy", "surprised"]`.

You can also give tags values that can be accessed with the `get_tag_value` method on a `DialogueLine`:

```
Nathan: [#mood=happy] Oh, Hello!
```

For this line of dialogue, the `tags` array would be `["mood=happy"]`, and `line.get_tag_value("mood")` would return `"happy"`.

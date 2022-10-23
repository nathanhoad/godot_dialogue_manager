# C# wrapper

If you are using C# for your project then there is a small convenience wrapper around the Dialogue Manager.

First, add the namespace:

```cs
using DialogueManagerRuntime;
```

Then you can load a dialogue resource and show the example balloon:

```cs
var dialogue = GD.Load<Resource>("res://example.dialogue");
DialogueManager.ShowExampleDialogueBalloon(dialogue, "start");
```

Or manually traverse dialogue:

```cs
var line = await DialogueManager.GetNextDialogueLine(dialogue, "start");
```

The returned line is a `Godot.Collections.Dictionary` and will have a similar shape to that of [the GDScript version](API.md).
# C# wrapper

If you are using C# for your project then there is a small convenience wrapper around the Dialogue Manager.

First, add the namespace:

```cs
using DialogueManagerRuntime;
```

Then you can load a dialogue resource and show the example balloon:

```cs
var dialogue = GD.Load<Resource>("res://example.tres");
DialogueManager.ShowExampleDialogueBalloon("start", dialogue);
```

Or manually traverse dialogue:

```cs
var line = await DialogueManager.GetNextDialogueLine("start", dialogue);
```

The returned line is a `Godot.Collections.Dictionary`.
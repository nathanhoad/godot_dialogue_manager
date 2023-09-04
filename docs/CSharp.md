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

The returned line is a `DialogueLine` and will have mostly the same properties to the [the GDScript version](API.md).

## Mutations

When writing mutations in C#, you'll generally want an `async` method that returns a `Task`. Here is an example method from the C# Example:

```csharp
public async Task AskForName()
{
  var nameInputDialogue = GD.Load<PackedScene>("res://examples/name_input_dialog/name_input_dialog.tscn").Instantiate() as AcceptDialog;
  GetTree().Root.AddChild(nameInputDialogue);
  nameInputDialogue.PopupCentered();

  await ToSignal(nameInputDialogue, "confirmed");
  PlayerName = nameInputDialogue.GetNode<LineEdit>("NameEdit").Text;
  nameInputDialogue.QueueFree();
}
```

And you would need to declar that `PlayerName` property like so (make sure to inclue the `[Export]` decorator or the Dialogue Manager won't be able to see it):

```csharp
[Export]
string PlayerName = "Player";
```

Then, in your dialogue you would call the mutation like this:

```
do AskForName()
Nathan: Hello {{PlayerName}}!
```

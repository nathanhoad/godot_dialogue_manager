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

## State

When looking for state, the Dialogue Manager will search in the current scene (ie. the scene returned from `GetTree().CurrentScene`), any autoloads, as well as anything passed in to the `extraGameStates` array in `GetNextDialogueLine(resource, key, extraGameStates)`. In order for a property to be visible to the Dialogue Manager it needs to have the `[Export]` decorator applied.

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

And you would need to declare that `PlayerName` property like so (make sure to include the `[Export]` decorator or the Dialogue Manager won't be able to see it):

```csharp
[Export] string PlayerName = "Player";
```

Then, in your dialogue you would call the mutation like this:

```
do AskForName()
Nathan: Hello {{PlayerName}}!
```

## Example

There is a balloon implemented in C# in the **examples** folder of the repository. If you want to have a closer look at it you'll have to clone the repository down because the automatic download ZIP removes the docs and examples folder.

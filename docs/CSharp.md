# C# wrapper

If you are using C# for your project, there is a small convenience wrapper around the Dialogue Manager.

First, add the namespace:

```cs
using DialogueManagerRuntime;
```

Then you can load a dialogue resource and show the example balloon:

```cs
var dialogue = GD.Load<Resource>("res://example.dialogue");
DialogueManager.ShowExampleDialogueBalloon(dialogue, "start");
```

Or show your custom balloon (if configured):

```cs
var dialogue = GD.Load<Resource>("res://example.dialogue");
DialogueManager.ShowDialogueBalloon(dialogue, "start");
```

Or manually traverse dialogue:

```cs
var line = await DialogueManager.GetNextDialogueLine(dialogue, "start");
```

The returned line is a `DialogueLine` and will have mostly the same properties to the [the GDScript version](API.md).

## State

When looking for state, the Dialogue Manager will search in the current scene (i.e. the scene returned from `GetTree().CurrentScene`), any autoloads, as well as anything passed in to the `extraGameStates` array in `GetNextDialogueLine(resource, key, extraGameStates)`. In order for a property to be visible to the Dialogue Manager, it needs to have the `[Export]` decorator applied.

## Mutations

When writing mutations in C#, you'll generally want an `async` method that returns a `Task`. Here is an example method for asking for a player's name and storing it in a property called `PlayerName`:

```csharp
public async Task AskForName()
{
  var nameInputDialogue = GD.Load<PackedScene>("res://path/to/some/name_input_dialog.tscn").Instantiate() as AcceptDialog;
  GetTree().Root.AddChild(nameInputDialogue);
  nameInputDialogue.PopupCentered();
  await ToSignal(nameInputDialogue, "confirmed");
  PlayerName = nameInputDialogue.GetNode<LineEdit>("NameEdit").Text;
  nameInputDialogue.QueueFree();
}
```

You would need to declare that `PlayerName` property like this:

```csharp
[Export] string PlayerName = "Player";
```

Then, in your dialogue you would call the mutation like this:

```
do AskForName()
Nathan: Hello {{PlayerName}}!
```

If you wanted to do the same thing but instead of storing it in the same property each time you can return the value as a `Variant`:

```csharp
public async Task<Variant> AskForName()
{
  var nameInputDialogue = GD.Load<PackedScene>("res://path/to/some/name_input_dialog.tscn").Instantiate() as AcceptDialog;
  GetTree().Root.AddChild(nameInputDialogue);
  nameInputDialogue.PopupCentered();\
  await ToSignal(nameInputDialogue, "confirmed");
  nameInputDialogue.QueueFree();
  return nameInputDialogue.GetNode<LineEdit>("NameEdit").Text;
}
```

## Signals

There are two ways you can connect to the Dialogue Manager signals - using `Connect` + `Callable` or by attaching event handlers.

Using event handlers is the simpler method (but only works on the Dialogue Manager itself):

```csharp
DialogueManager.DialogueStarted += (Resource dialogueResource) =>
{
  // ...
};

DialogueManager.DialogueEnded += (Resource dialogueResource) =>
{
  // ...
};

DialogueManager.PassedTitle += (string title) =>
{
  // ...
};

DialogueManager.GotDialogue += (DialogueLine line) =>
{
  // ...
};

DialogueManager.Mutated += (Godot.Collections.Dictionary mutation) =>
{
  // ...
};
```

If you are using the built-in responses menu node, you'll have to use the `Connect` approach:

```csharp
responsesMenu.Connect("response_selected", Callable.From((DialogueResponse response) =>
{
  // ...
}));
```

## Generating Dialogue Resources at runtime

If you need to construct a dialogue resource at runtime, you can use `CreateResoureFromString(string)`:
Please note, a balloon or Dialogue must be opened for the dialogue to attach to.

```csharp
var resource = DialogueManager.CreateResourceFromText("~ title\nCharacter: Hello!");
```

This will run the given text through the parser.

If there were syntax errors, the method will fail.

If there were no errors, you can use this ephemeral resource like normal:

```csharp
 var line = DialogueManager.ShowExampleDialogueBalloon(resource, "start");
```

## Examples

There are a few example projects available on [my Itch.io](https://nathanhoad.itch.io) page, all of which include C# versions of the entire project.

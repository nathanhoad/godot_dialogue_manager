using Godot;

public partial class TestScene : Node2D
{
  [Export]
  PackedScene Balloon;

  [Export]
  PackedScene SmallBalloon;

  [Export]
  string Title = "start";

  [Export]
  Resource DialogueResource;


  public async override void _Ready()
  {
    Engine.GetSingleton("DialogueManager").Connect("dialogue_finished", new Callable(this, "OnDialogueFinished"));

    await ToSignal(GetTree().CreateTimer(0.4), "timeout");

    // Show the dialogue
    bool isSmallWindow = (int)ProjectSettings.GetSetting("display/window/size/viewport_width") < 400;
    Balloon balloon = (Balloon)(isSmallWindow ? SmallBalloon : Balloon).Instantiate();
    AddChild(balloon);
    balloon.Start(DialogueResource, Title);
  }


  private async void OnDialogueFinished()
  {
    await ToSignal(GetTree().CreateTimer(0.4), "timeout");
    GetTree().Quit();
  }
}

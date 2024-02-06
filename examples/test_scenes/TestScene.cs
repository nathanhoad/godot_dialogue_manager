using Godot;
using DialogueManagerRuntime;
using System.Threading.Tasks;

public partial class TestScene : Node2D
{
    [Export] PackedScene Balloon;

    [Export] PackedScene SmallBalloon;

    [Export] string Title = "start";

    [Export] Resource DialogueResource;

    /* Make sure to add an [Export] decorator so that the Dialogue Manager can see the property */
    [Export] string PlayerName = "Player";
    [Export] int TreatsCount = 0;


    public async override void _Ready()
    {
        DialogueManager.DialogueEnded += async (Resource dialogueResource) =>
        {
            await ToSignal(GetTree().CreateTimer(0.4), "timeout");
            GetTree().Quit();
        };

        await ToSignal(GetTree().CreateTimer(0.4), "timeout");

        // Show the dialogue
        bool isSmallWindow = (int)ProjectSettings.GetSetting("display/window/size/viewport_width") < 400;
        DialogueManager.ShowDialogueBalloonScene(isSmallWindow ? SmallBalloon : Balloon, DialogueResource, Title);
    }


    public async Task AskForName(string defaultName = "Player")
    {
        var nameInputDialogue = GD.Load<PackedScene>("res://examples/name_input_dialog/name_input_dialog.tscn").Instantiate() as AcceptDialog;
        var nameInput = nameInputDialogue.GetNode<LineEdit>("NameEdit");
        GetTree().Root.AddChild(nameInputDialogue);
        nameInputDialogue.PopupCentered();
        nameInput.Text = defaultName;
        await ToSignal(nameInputDialogue, "confirmed");
        PlayerName = nameInput.Text;
        nameInputDialogue.QueueFree();
    }
}

using Godot;
using Godot.Collections;
using DialogueManagerRuntime;

public partial class Balloon : CanvasLayer
{
  Panel balloon;
  RichTextLabel characterLabel;
  RichTextLabel dialogueLabel;
  VBoxContainer responsesMenu;

  Resource resource;
  Array<Variant> temporaryGameStates = new Array<Variant>();
  bool isWaitingForInput = false;
  bool willHideBalloon = false;

  DialogueLine dialogueLine;
  DialogueLine DialogueLine
  {
    get => dialogueLine;
    set
    {
      isWaitingForInput = false;

      if (value == null)
      {
        QueueFree();
        return;
      }

      dialogueLine = value;
      UpdateDialogueLine();
    }
  }


  public override void _Ready()
  {
    balloon = GetNode<Panel>("%Balloon");
    characterLabel = GetNode<RichTextLabel>("%CharacterLabel");
    dialogueLabel = GetNode<RichTextLabel>("%DialogueLabel");
    responsesMenu = GetNode<VBoxContainer>("%ResponsesMenu");

    balloon.Hide();

    balloon.GuiInput += (inputEvent) =>
    {
      // Finish typing out the dialogue if we click the mouse
      if ((bool)dialogueLabel.Get("is_typing") && inputEvent is InputEventMouseButton && (inputEvent as InputEventMouseButton).ButtonIndex == MouseButton.Left && inputEvent.IsPressed())
      {
        GetViewport().SetInputAsHandled();
        dialogueLabel.Call("skip_typing");
        return;
      }

      if (!isWaitingForInput) return;
      if (dialogueLine.Responses.Count > 0) return;

      GetViewport().SetInputAsHandled();

      if (inputEvent is InputEventMouseButton && inputEvent.IsPressed() && (inputEvent as InputEventMouseButton).ButtonIndex == MouseButton.Left)
      {
        Next(dialogueLine.NextId);
      }
      else if (inputEvent.IsActionPressed("ui_accept") && GetViewport().GuiGetFocusOwner() == balloon)
      {
        Next(dialogueLine.NextId);
      }
    };

    responsesMenu.Connect("response_selected", Callable.From((DialogueResponse response) =>
    {
      Next(response.NextId);
    }));

    Engine.GetSingleton("DialogueManager").Connect("mutated", Callable.From((Dictionary mutation) =>
    {
      isWaitingForInput = false;
      willHideBalloon = true;
      GetTree().CreateTimer(0.1f).Timeout += () =>
      {
        if (willHideBalloon)
        {
          willHideBalloon = false;
          balloon.Hide();
        }
      };
    }));
  }


  public override void _UnhandledInput(InputEvent inputEvent)
  {
    // Only the balloon is allowed to handle input while it's showing
    GetViewport().SetInputAsHandled();
  }


  public async void Start(Resource dialogueResource, string title, Array<Variant> extraGameStates = null)
  {
    temporaryGameStates = extraGameStates ?? new Array<Variant>();
    isWaitingForInput = false;
    resource = dialogueResource;

    DialogueLine = await DialogueManager.GetNextDialogueLine(resource, title, temporaryGameStates);
  }


  #region Helpers


  private async void Next(string nextId)
  {
    DialogueLine = await DialogueManager.GetNextDialogueLine(resource, nextId, temporaryGameStates);
  }


  private async void UpdateDialogueLine()
  {
    // Set up the character and dialogue
    characterLabel.Visible = !string.IsNullOrEmpty(dialogueLine.Character);
    characterLabel.Text = dialogueLine.Character;
    dialogueLabel.Hide();
    dialogueLabel.Set("dialogue_line", dialogueLine);

    // Set up the responses if there are any
    responsesMenu.Hide();
    responsesMenu.Set("responses", dialogueLine.Responses);

    // Show the balloon
    balloon.Show();
    willHideBalloon = false;

    // Type out the dialogue if there is any
    dialogueLabel.Show();
    if (!string.IsNullOrEmpty(dialogueLine.Text))
    {
      dialogueLabel.Call("type_out");
      await ToSignal(dialogueLabel, "finished_typing");
    }

    // Wait for input
    if (dialogueLine.Responses.Count > 0)
    {
      balloon.FocusMode = Control.FocusModeEnum.None;
      responsesMenu.Show();
    }
    else if (!string.IsNullOrEmpty(dialogueLine.Time))
    {
      float time = 0f;
      if (!float.TryParse(dialogueLine.Time, out time))
      {
        time = dialogueLine.Text.Length * 0.02f;
      }
      await ToSignal(GetTree().CreateTimer(time), "timeout");
      Next(dialogueLine.NextId);
    }
    else
    {
      isWaitingForInput = true;
      balloon.FocusMode = Control.FocusModeEnum.All;
      balloon.GrabFocus();
    }
  }


  #endregion
}



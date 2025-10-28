using Godot;
using Godot.Collections;

namespace DialogueManagerRuntime
{
  public partial class ExampleBalloon : CanvasLayer
  {
    [Export] public Resource DialogueResource;
    [Export] public string StartFromTitle = "";
    [Export] public bool AutoStart = false;
    [Export] public string NextAction = "ui_accept";
    [Export] public string SkipAction = "ui_cancel";


    Control balloon;
    RichTextLabel characterLabel;
    RichTextLabel dialogueLabel;
    VBoxContainer responsesMenu;
    Polygon2D progress;

    Array<Variant> temporaryGameStates = new Array<Variant>();
    bool isWaitingForInput = false;
    bool willHideBalloon = false;

    DialogueLine dialogueLine;
    DialogueLine DialogueLine
    {
      get => dialogueLine;
      set
      {
        // Dialogue has finished so close the balloon
        if (value == null)
        {
          if (Owner == null)
          {
            QueueFree();
          }
          else
          {
            Hide();
          }
          return;
        }

        dialogueLine = value;
        ApplyDialogueLine();
      }
    }

    Timer MutationCooldown = new Timer();


    public override void _Ready()
    {
      balloon = GetNode<Control>("%Balloon");
      characterLabel = GetNode<RichTextLabel>("%CharacterLabel");
      dialogueLabel = GetNode<RichTextLabel>("%DialogueLabel");
      responsesMenu = GetNode<VBoxContainer>("%ResponsesMenu");
      progress = GetNode<Polygon2D>("%Progress");

      balloon.Hide();

      balloon.GuiInput += (@event) =>
      {
        if ((bool)dialogueLabel.Get("is_typing"))
        {
          bool mouseWasClicked = @event is InputEventMouseButton && (@event as InputEventMouseButton).ButtonIndex == MouseButton.Left && @event.IsPressed();
          bool skipButtonWasPressed = @event.IsActionPressed(SkipAction);
          if (mouseWasClicked || skipButtonWasPressed)
          {
            GetViewport().SetInputAsHandled();
            dialogueLabel.Call("skip_typing");
            return;
          }
        }

        if (!isWaitingForInput) return;
        if (dialogueLine.Responses.Count > 0) return;

        GetViewport().SetInputAsHandled();

        if (@event is InputEventMouseButton && @event.IsPressed() && (@event as InputEventMouseButton).ButtonIndex == MouseButton.Left)
        {
          Next(dialogueLine.NextId);
        }
        else if (@event.IsActionPressed(NextAction) && GetViewport().GuiGetFocusOwner() == balloon)
        {
          Next(dialogueLine.NextId);
        }
      };

      if (string.IsNullOrEmpty((string)responsesMenu.Get("next_action")))
      {
        responsesMenu.Set("next_action", NextAction);
      }
      responsesMenu.Connect("response_selected", Callable.From((DialogueResponse response) =>
      {
        Next(response.NextId);
      }));


      // Hide the balloon when a mutation is running
      MutationCooldown.Timeout += () =>
      {
        if (willHideBalloon)
        {
          willHideBalloon = false;
          balloon.Hide();
        }
      };
      AddChild(MutationCooldown);

      DialogueManager.Mutated += OnMutated;

      if (AutoStart)
      {
        if (!IsInstanceValid(DialogueResource))
        {
          throw new System.Exception(DialogueManager.GetErrorMessage(143));
        }
        Start();
      }
    }


    public override void _ExitTree()
    {
      DialogueManager.Mutated -= OnMutated;
    }


    public override void _UnhandledInput(InputEvent @event)
    {
      // Only the balloon is allowed to handle input while it's showing
      GetViewport().SetInputAsHandled();
    }


    public override async void _Notification(int what)
    {
      // Detect a change of locale and update the current dialogue line to show the new language
      if (what == NotificationTranslationChanged && IsInstanceValid(dialogueLabel))
      {
        float visibleRatio = dialogueLabel.VisibleRatio;
        DialogueLine = await DialogueManager.GetNextDialogueLine(DialogueResource, DialogueLine.Id, temporaryGameStates);
        if (visibleRatio < 1.0f)
        {
          dialogueLabel.Call("skip_typing");
        }
      }
    }


    public override void _Process(double delta)
    {
      base._Process(delta);

      if (IsInstanceValid(dialogueLine))
      {
        progress.Visible = !(bool)dialogueLabel.Get("is_typing") && dialogueLine.Responses.Count == 0 && !dialogueLine.HasTag("voice");
      }
    }


    public async void Start(Resource dialogueResource = null, string title = "", Array<Variant> extraGameStates = null)
    {
      temporaryGameStates = new Array<Variant> { this } + (extraGameStates ?? new Array<Variant>());
      isWaitingForInput = false;

      if (IsInstanceValid(dialogueResource))
      {
        DialogueResource = dialogueResource;
      }
      if (title != "")
      {
        StartFromTitle = title;
      }

      DialogueLine = await DialogueManager.GetNextDialogueLine(DialogueResource, StartFromTitle, temporaryGameStates);
      Show();
    }


    public async void Next(string nextId)
    {
      DialogueLine = await DialogueManager.GetNextDialogueLine(DialogueResource, nextId, temporaryGameStates);
    }


    #region Helpers


    private async void ApplyDialogueLine()
    {
      MutationCooldown.Stop();

      isWaitingForInput = false;
      balloon.FocusMode = Control.FocusModeEnum.All;
      balloon.GrabFocus();

      // Set up the character name
      characterLabel.Visible = !string.IsNullOrEmpty(dialogueLine.Character);
      characterLabel.Text = Tr(dialogueLine.Character, "dialogue");

      // Set up the dialogue
      dialogueLabel.Hide();
      dialogueLabel.Set("dialogue_line", dialogueLine);

      // Set up the responses
      responsesMenu.Hide();
      responsesMenu.Set("responses", dialogueLine.Responses);

      // Type out the text
      balloon.Show();
      willHideBalloon = false;
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


    #region signals


    private void OnMutated(Dictionary _mutation)
    {
      isWaitingForInput = false;
      willHideBalloon = true;
      MutationCooldown.Start(0.1f);
    }


    #endregion
  }
}

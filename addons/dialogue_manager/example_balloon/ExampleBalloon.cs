using Godot;
using Godot.Collections;

namespace DialogueManagerRuntime
{
  public partial class ExampleBalloon : CanvasLayer
  {
    [Export] public Resource DialogueResource;
    [Export] public string StartFromLabel = "";
    [Export] public bool AutoStart = false;
    [Export] public string NextAction = "ui_accept";
    [Export] public string SkipAction = "ui_cancel";


    Control balloon;
    RichTextLabel characterLabel;
    DialogueLabel dialogueLabel;
    DialogueResponsesMenu responsesMenu;
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
      dialogueLabel = GetNode<DialogueLabel>("%DialogueLabel");
      responsesMenu = GetNode<DialogueResponsesMenu>("%ResponsesMenu");
      progress = GetNode<Polygon2D>("%Progress");

      balloon.Hide();

      balloon.GuiInput += (@event) =>
      {
        if (dialogueLabel.IsTyping)
        {
          bool mouseWasClicked = @event is InputEventMouseButton && (@event as InputEventMouseButton).ButtonIndex == MouseButton.Left && @event.IsPressed();
          bool skipButtonWasPressed = @event.IsActionPressed(SkipAction);
          if (mouseWasClicked || skipButtonWasPressed)
          {
            GetViewport().SetInputAsHandled();
            dialogueLabel.SkipTyping();
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

      if (string.IsNullOrEmpty(responsesMenu.NextAction))
      {
        responsesMenu.NextAction = NextAction;
      }
      responsesMenu.ResponseSelected += (response) =>
      {
        Next(response.NextId);
      };


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

      // EXAMPLE MESSAGE
      var warning = new Button
      {
        Text = DialogueManager.Translate("This is an example balloon. Create your own balloon in 'Project > Tools > Dialogue > Create Balloon...'"),
        Disabled = true
      };
      warning.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.TopWide);
      balloon.AddChild(warning);
      balloon.MoveChild(warning, 0);
      // END EXAMPLE MESSAGE
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
          dialogueLabel.SkipTyping();
        }
      }
    }


    public override void _Process(double delta)
    {
      base._Process(delta);

      if (IsInstanceValid(dialogueLine))
      {
        progress.Visible = !dialogueLabel.IsTyping && dialogueLine.Responses.Count == 0 && !dialogueLine.HasTag("voice");
      }
    }


    public async void Start(Resource dialogueResource = null, string label = "", Array<Variant> extraGameStates = null)
    {
      temporaryGameStates = new Array<Variant> { this } + (extraGameStates ?? new Array<Variant>());
      isWaitingForInput = false;

      if (IsInstanceValid(dialogueResource))
      {
        DialogueResource = dialogueResource;
      }
      if (label != "")
      {
        StartFromLabel = label;
      }

      DialogueLine = await DialogueManager.GetNextDialogueLine(DialogueResource, StartFromLabel, temporaryGameStates);
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
      dialogueLabel.DialogueLine = dialogueLine;

      // Set up the responses
      responsesMenu.Hide();
      responsesMenu.Responses = dialogueLine.Responses;

      // Type out the text
      balloon.Show();
      willHideBalloon = false;
      dialogueLabel.Show();
      if (!string.IsNullOrEmpty(dialogueLine.Text))
      {
        dialogueLabel.TypeOut();
        await ToSignal(dialogueLabel, DialogueLabel.SignalName.FinishedTyping);
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
        await ToSignal(GetTree().CreateTimer(time), Timer.SignalName.Timeout);
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


    private void OnMutated(Dictionary mutation)
    {
      if (!(bool)mutation["is_inline"])
      {
        isWaitingForInput = false;
        willHideBalloon = true;
        MutationCooldown.Start(0.1f);
      }
    }


    #endregion
  }
}

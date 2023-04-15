using Godot;
using Godot.Collections;
using DialogueManagerRuntime;

public partial class Balloon : CanvasLayer
{
  Color VISIBLE = new Color(1f, 1f, 1f, 1f);
  Color INVISIBLE = new Color(1f, 1f, 1f, 0f);

  GDScript DialogueLabel = GD.Load<GDScript>("res://addons/dialogue_manager/dialogue_label.gd");

  ColorRect balloon;
  MarginContainer margin;
  RichTextLabel characterLabel;
  RichTextLabel dialogueLabel;
  VBoxContainer responsesMenu;
  RichTextLabel responseTemplate;

  Resource resource;
  Array<Variant> temporaryGameStates = new Array<Variant>();
  bool isWaitingForInput = false;

  GodotObject dialogueLine;
  GodotObject DialogueLine
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
    balloon = GetNode<ColorRect>("Balloon");
    margin = GetNode<MarginContainer>("Balloon/Margin");
    characterLabel = GetNode<RichTextLabel>("Balloon/Margin/VBox/CharacterLabel");
    dialogueLabel = GetNode<RichTextLabel>("Balloon/Margin/VBox/DialogueLabel");
    responsesMenu = GetNode<VBoxContainer>("Balloon/Margin/VBox/Responses");
    responseTemplate = GetNode<RichTextLabel>("Balloon/Margin/VBox/ResponseTemplate");

    responseTemplate.Hide();
    balloon.Hide();
    balloon.CustomMinimumSize = new Vector2(balloon.GetViewportRect().Size.X, balloon.CustomMinimumSize.Y);

    balloon.GuiInput += (inputEvent) =>
    {

      if (!isWaitingForInput) return;
      if (GetResponses().Count > 0) return;

      GetViewport().SetInputAsHandled();

      if (inputEvent is InputEventMouseButton && inputEvent.IsPressed() && (inputEvent as InputEventMouseButton).ButtonIndex == MouseButton.Left)
      {
        Next((string)dialogueLine.Get("next_id"));
      }
      else if (inputEvent.IsActionPressed("ui_accept") && GetViewport().GuiGetFocusOwner() == balloon)
      {
        Next((string)dialogueLine.Get("next_id"));
      }

    };

    margin.Resized += () => HandleResize();

    Engine.GetSingleton("DialogueManager").Connect("mutated", Callable.From((Dictionary mutation) =>
    {
      isWaitingForInput = false;
      balloon.Hide();
    }));
  }


  public override void _UnhandledInput(InputEvent inputEvent)
  {
    // Only the balloon is allowed to handle input while it's showing
    GetViewport().SetInputAsHandled();
  }


  public async void Start(Resource dialogueResource, string title, Array<Variant> extraGameStates = null)
  {
    temporaryGameStates = extraGameStates;
    isWaitingForInput = false;
    resource = dialogueResource;

    DialogueLine = await DialogueManager.GetNextDialogueLine(resource, title, temporaryGameStates ?? new Array<Variant>());
  }


  private async void Next(string nextId)
  {
    DialogueLine = await DialogueManager.GetNextDialogueLine(resource, nextId, temporaryGameStates ?? new Array<Variant>());
  }


  /// Helpers


  private void ConfigureMenu()
  {
    balloon.FocusMode = Control.FocusModeEnum.None;

    var items = GetResponses();
    for (int i = 0; i < items.Count; i++)
    {
      var item = items[i];

      item.FocusMode = Control.FocusModeEnum.All;

      item.FocusNeighborLeft = item.GetPath();
      item.FocusNeighborRight = item.GetPath();

      if (i == 0)
      {
        item.FocusNeighborTop = item.GetPath();
        item.FocusPrevious = item.GetPath();
      }
      else
      {
        item.FocusNeighborTop = items[i - 1].GetPath();
        item.FocusPrevious = items[i - 1].GetPath();
      }

      if (i == items.Count - 1)
      {
        item.FocusNeighborBottom = item.GetPath();
        item.FocusNext = item.GetPath();
      }
      else
      {
        item.FocusNeighborBottom = items[i + 1].GetPath();
        item.FocusNext = items[i + 1].GetPath();
      }

      item.MouseEntered += () =>
      {
        if (item.Name.ToString().Contains("Disallowed")) return;

        item.GrabFocus();
      };
      item.GuiInput += (inputEvent) =>
      {
        if (item.Name.ToString().Contains("Disallowed")) return;

        if (inputEvent is InputEventMouseButton && inputEvent.IsPressed() && (inputEvent as InputEventMouseButton).ButtonIndex == MouseButton.Left)
        {
          Next((string)((Array<RefCounted>)dialogueLine.Get("responses"))[item.GetIndex()].Get("next_id"));
        }
        else if (inputEvent.IsActionPressed("ui_accept") && GetResponses().Contains(item))
        {
          Next((string)((Array<RefCounted>)dialogueLine.Get("responses"))[item.GetIndex()].Get("next_id"));
        }
      };
    }

    items[0].GrabFocus();
  }


  private Array<Control> GetResponses()
  {
    Array<Control> items = new Array<Control>();
    foreach (Control child in responsesMenu.GetChildren())
    {
      if (child.Name.ToString().Contains("Disallowed")) continue;

      items.Add(child);
    }

    return items;
  }


  private void HandleResize()
  {
    if (!IsInstanceValid(margin))
    {
      CallDeferred("HandleResize");
      return;
    }

    balloon.CustomMinimumSize = new Vector2(balloon.CustomMinimumSize.X, margin.Size.Y);
    balloon.Size = new Vector2(balloon.Size.X, 0);
    Vector2 viewportSize = balloon.GetViewportRect().Size;
    balloon.GlobalPosition = new Vector2((viewportSize.X - balloon.Size.X) * 0.5f, viewportSize.Y - balloon.Size.Y);
  }


  private async void UpdateDialogueLine()
  {
    foreach (Control child in responsesMenu.GetChildren())
    {
      child.Free();
    }

    characterLabel.Visible = !string.IsNullOrEmpty((string)dialogueLine.Get("character"));
    characterLabel.Text = (string)(dialogueLine.Get("character"));

    dialogueLabel.Modulate = INVISIBLE;
    dialogueLabel.CustomMinimumSize = new Vector2(dialogueLabel.GetParent<Control>().Size.X - 1, dialogueLabel.CustomMinimumSize.Y);
    dialogueLabel.Set("dialogue_line", dialogueLine);

    // Show any responses we have
    responsesMenu.Modulate = INVISIBLE;
    foreach (var response in (Array<RefCounted>)dialogueLine.Get("responses"))
    {
      RichTextLabel item = (RichTextLabel)responseTemplate.Duplicate();
      item.Name = $"Response{responsesMenu.GetChildCount()}";
      if (!(bool)response.Get("is_allowed"))
      {
        item.Name = item.Name + "Disallowed";
        item.Modulate = new Color(item.Modulate, 0.4f);
      }
      item.Text = (string)response.Get("text");
      item.Show();
      responsesMenu.AddChild(item);
    }

    // Show the balloon
    balloon.Show();

    dialogueLabel.Modulate = VISIBLE;
    if (!string.IsNullOrEmpty((string)dialogueLine.Get("text")))
    {
      dialogueLabel.Call("type_out");
      await ToSignal(dialogueLabel, "finished_typing");
    }

    // Wait for input
    if (((Array<RefCounted>)dialogueLine.Get("responses")).Count > 0)
    {
      responsesMenu.Modulate = VISIBLE;
      ConfigureMenu();
    }
    else if (!string.IsNullOrEmpty((string)dialogueLine.Get("time")))
    {
      float time = 0f;
      if (!float.TryParse((string)dialogueLine.Get("time"), out time))
      {
        time = ((string)dialogueLine.Get("text")).Length * 0.02f;
      }
      await ToSignal(GetTree().CreateTimer(time), "timeout");
      Next((string)dialogueLine.Get("next_id"));
    }
    else
    {
      isWaitingForInput = true;
      balloon.FocusMode = Control.FocusModeEnum.All;
    }
  }
}



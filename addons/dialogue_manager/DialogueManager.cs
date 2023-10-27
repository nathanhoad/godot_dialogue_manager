using Godot;
using Godot.Collections;
using System;
using System.Reflection;
using System.Threading.Tasks;

#nullable enable

namespace DialogueManagerRuntime
{
  public enum TranslationSource
  {
    None,
    Guess,
    CSV,
    PO
  }

  public partial class DialogueManager : Node
  {
    public delegate void PassedTitleEventHandler(string title);
    public delegate void GotDialogueEventHandler(DialogueLine dialogueLine);
    public delegate void MutatedEventHandler(Dictionary mutation);
    public delegate void DialogueEndedEventHandler(Resource dialogueResource);

    public static PassedTitleEventHandler? PassedTitle;
    public static GotDialogueEventHandler? GotDialogue;
    public static MutatedEventHandler? Mutated;
    public static DialogueEndedEventHandler? DialogueEnded;

    [Signal] public delegate void ResolvedEventHandler(Variant value);

    private static GodotObject? instance;
    public static GodotObject Instance
    {
      get
      {
        if (instance == null)
        {
          instance = Engine.GetSingleton("DialogueManager");
        }
        return instance;
      }
    }


    public static Godot.Collections.Array GameStates
    {
      get => (Godot.Collections.Array)Instance.Get("game_states");
      set => Instance.Set("game_states", value);
    }


    public static bool IncludeSingletons
    {
      get => (bool)Instance.Get("include_singletons");
      set => Instance.Set("include_singletons", value);
    }


    public static bool IncludeClasses
    {
      get => (bool)Instance.Get("include_classes");
      set => Instance.Set("include_classes", value);
    }


    public static TranslationSource TranslationSource
    {
      get => (TranslationSource)(int)Instance.Get("translation_source");
      set => Instance.Set("translation_source", (int)value);
    }


    public static Func<Node> GetCurrentScene
    {
      set => Instance.Set("get_current_scene", Callable.From(value));
    }


    public void Prepare()
    {
      Instance.Connect("passed_title", Callable.From((string title) => PassedTitle?.Invoke(title)));
      Instance.Connect("got_dialogue", Callable.From((RefCounted line) => GotDialogue?.Invoke(new DialogueLine(line))));
      Instance.Connect("mutated", Callable.From((Dictionary mutation) => Mutated?.Invoke(mutation)));
      Instance.Connect("dialogue_ended", Callable.From((Resource dialogueResource) => DialogueEnded?.Invoke(dialogueResource)));
    }


    public static async Task<GodotObject> GetSingleton()
    {
      if (instance != null) return instance;

      var tree = Engine.GetMainLoop();
      int x = 0;

      // Try and find the singleton for a few seconds
      while (!Engine.HasSingleton("DialogueManager") && x < 300)
      {
        await tree.ToSignal(tree, SceneTree.SignalName.ProcessFrame);
        x++;
      }

      // If it times out something is wrong
      if (x >= 300)
      {
        throw new Exception("The DialogueManager singleton is missing.");
      }

      instance = Engine.GetSingleton("DialogueManager");
      return instance;
    }


    public static async Task<DialogueLine?> GetNextDialogueLine(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
    {
      Instance.Call("_bridge_get_next_dialogue_line", dialogueResource, key, extraGameStates ?? new Array<Variant>());
      var result = await Instance.ToSignal(Instance, "bridge_get_next_dialogue_line_completed");

      if ((RefCounted)result[0] == null) return null;

      return new DialogueLine((RefCounted)result[0]);
    }


    public static CanvasLayer ShowExampleDialogueBalloon(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
    {
      return (CanvasLayer)Instance.Call("show_example_dialogue_balloon", dialogueResource, key, extraGameStates ?? new Array<Variant>());
    }


    public bool ThingHasMethod(GodotObject thing, string method)
    {
      MethodInfo? info = thing.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly);
      return info != null;
    }

    public async void ResolveThingMethod(GodotObject thing, string method, Array<Variant> args)
    {
      MethodInfo? info = thing.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly);

      if (info == null) return;

#nullable disable
      // Convert the method args to something reflection can handle
      ParameterInfo[] argTypes = info.GetParameters();
      object[] _args = new object[argTypes.Length];
      for (int i = 0; i < argTypes.Length; i++)
      {
        if (i < args.Count && args[i].Obj != null)
        {
          _args[i] = Convert.ChangeType(args[i].Obj, argTypes[i].ParameterType);
        }
        else if (argTypes[i].DefaultValue != null)
        {
          _args[i] = argTypes[i].DefaultValue;
        }
      }

      if (info.ReturnType == typeof(Task))
      {
        await (Task)info.Invoke(thing, _args);
        EmitSignal(SignalName.Resolved, null);
      }
      else
      {
        var value = (Variant)info.Invoke(thing, _args);
        EmitSignal(SignalName.Resolved, value);
      }
    }
#nullable enable
  }


  public partial class DialogueLine : RefCounted
  {
    private string type = "dialogue";
    public string Type
    {
      get => type;
      set => type = value;
    }

    private string next_id = "";
    public string NextId
    {
      get => next_id;
      set => next_id = value;
    }

    private string character = "";
    public string Character
    {
      get => character;
      set => character = value;
    }

    private string text = "";
    public string Text
    {
      get => text;
      set => text = value;
    }

    private string translation_key = "";
    public string TranslationKey
    {
      get => translation_key;
      set => translation_key = value;
    }

    private Array<DialogueResponse> responses = new Array<DialogueResponse>();
    public Array<DialogueResponse> Responses
    {
      get => responses;
    }

    private string? time = null;
    public string? Time
    {
      get => time;
    }

    private Dictionary pauses = new Dictionary();
    private Dictionary speeds = new Dictionary();

    private Array<Godot.Collections.Array> inline_mutations = new Array<Godot.Collections.Array>();

    private Array<Variant> extra_game_states = new Array<Variant>();



    public DialogueLine(RefCounted data)
    {
      type = (string)data.Get("type");
      next_id = (string)data.Get("next_id");
      character = (string)data.Get("character");
      text = (string)data.Get("text");
      translation_key = (string)data.Get("translation_key");
      pauses = (Dictionary)data.Get("pauses");
      speeds = (Dictionary)data.Get("speeds");
      inline_mutations = (Array<Godot.Collections.Array>)data.Get("inline_mutations");
      time = (string)data.Get("time");

      foreach (var response in (Array<RefCounted>)data.Get("responses"))
      {
        responses.Add(new DialogueResponse(response));
      }
    }
  }


  public partial class DialogueResponse : RefCounted
  {
    private string next_id = "";
    public string NextId
    {
      get => next_id;
      set => next_id = value;
    }

    private bool is_allowed = true;
    public bool IsAllowed
    {
      get => is_allowed;
      set => is_allowed = value;
    }

    private string text = "";
    public string Text
    {
      get => text;
      set => text = value;
    }

    private string translation_key = "";
    public string TranslationKey
    {
      get => translation_key;
      set => translation_key = value;
    }


    public DialogueResponse(RefCounted data)
    {
      next_id = (string)data.Get("next_id");
      is_allowed = (bool)data.Get("is_allowed");
      text = (string)data.Get("text");
      translation_key = (string)data.Get("translation_key");
    }
  }
}


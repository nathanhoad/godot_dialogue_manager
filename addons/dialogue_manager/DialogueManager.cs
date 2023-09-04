using Godot;
using Godot.Collections;
using System.Reflection;
using System.Threading.Tasks;

namespace DialogueManagerRuntime
{
  public partial class DialogueManager : Node
  {
    [Signal]
    public delegate void ResolvedEventHandler(Variant value);


    private static GodotObject? singleton;

    public static async Task<GodotObject> GetSingleton()
    {
      if (singleton != null) return singleton;

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
        throw new System.Exception("The DialogueManager singleton is missing.");
      }

      singleton = Engine.GetSingleton("DialogueManager");
      return singleton;
    }


    public static async Task<DialogueLine?> GetNextDialogueLine(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
    {
      var dialogueManager = Engine.GetSingleton("DialogueManager");
      dialogueManager.Call("_bridge_get_next_dialogue_line", dialogueResource, key, extraGameStates ?? new Array<Variant>());
      var result = await dialogueManager.ToSignal(dialogueManager, "bridge_get_next_dialogue_line_completed");

      if ((RefCounted)result[0] == null) return null;

      return new DialogueLine((RefCounted)result[0]);
    }


    public static void ShowExampleDialogueBalloon(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
    {
      Engine.GetSingleton("DialogueManager").Call("show_example_dialogue_balloon", dialogueResource, key, extraGameStates ?? new Array<Variant>());
    }


    public bool ThingHasMethod(GodotObject thing, string method)
    {
      MethodInfo info = thing.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly);
      return info != null;
    }


    public async void ResolveThingMethod(GodotObject thing, string method, Array<Variant> args)
    {
      // Convert the method args to something reflection can handle
      object[] _args = new object[args.Count];
      for (int i = 0; i < args.Count; i++)
      {
        _args[i] = args[i];
      }

      // Call the method
      MethodInfo info = thing.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly);
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

    private Array<Array> inline_mutations = new Array<Array>();

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
      inline_mutations = (Array<Array>)data.Get("inline_mutations");

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


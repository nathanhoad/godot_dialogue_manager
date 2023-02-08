using Godot;
using Godot.Collections;
using System.Threading.Tasks;

namespace DialogueManagerRuntime
{
  public partial class DialogueManager : Node
  {
    public static async Task<RefCounted> GetNextDialogueLine(Resource dialogueResource, string key = "0", Array<Variant> extraGameStates = null)
    {
      var dialogueManager = Engine.GetSingleton("DialogueManager");
      dialogueManager.Call("_bridge_get_next_dialogue_line", dialogueResource, key, extraGameStates ?? new Array<Variant>());
      var result = await dialogueManager.ToSignal(dialogueManager, "bridge_get_next_dialogue_line_completed");

      return (RefCounted)result[0];
    }


    public static void ShowExampleDialogueBalloon(Resource dialogueResource, string key = "0", Array<Variant> extraGameStates = null)
    {
      Engine.GetSingleton("DialogueManager").Call("show_example_dialogue_balloon", dialogueResource, key, extraGameStates ?? new Array<Variant>());
    }
  }
}
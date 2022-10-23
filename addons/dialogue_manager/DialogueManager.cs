using Godot;
using Godot.Collections;
using System;
using System.Threading.Tasks;

namespace DialogueManagerRuntime
{
  public partial class DialogueManager : Node
  {
    public static async Task<Dictionary> GetNextDialogueLine(Resource dialogueResource, string key = "0", Godot.Collections.Array<Variant> extraGameStates = null)
    {
      var dialogueManager = GetDialogueManager();
      dialogueManager.Call("_bridge_get_next_dialogue_line", dialogueResource, key, extraGameStates ?? new Godot.Collections.Array<Variant>());
      var result = await dialogueManager.ToSignal(dialogueManager, "bridge_get_next_dialogue_line_completed");

      return (Dictionary)result[0];
    }


    public static void ShowExampleDialogueBalloon(Resource dialogueResource, string key = "0", Godot.Collections.Array<Variant> extraGameStates = null)
    {
      GetDialogueManager().Call("show_example_dialogue_balloon", dialogueResource, key, extraGameStates ?? new Godot.Collections.Array<Variant>());
    }


    private static Node GetDialogueManager()
    {
      return ((SceneTree)Engine.GetMainLoop()).Root.GetNode("DialogueManager");
    }
  }
}

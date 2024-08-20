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


        public static Node ShowDialogueBalloonScene(string balloonScene, Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (Node)Instance.Call("show_dialogue_balloon_scene", balloonScene, dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }

        public static Node ShowDialogueBalloonScene(PackedScene balloonScene, Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (Node)Instance.Call("show_dialogue_balloon_scene", balloonScene, dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }

        public static Node ShowDialogueBalloonScene(Node balloonScene, Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (Node)Instance.Call("show_dialogue_balloon_scene", balloonScene, dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }


        public static Node ShowDialogueBalloon(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (Node)Instance.Call("show_dialogue_balloon", dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }


        public static async void Mutate(Dictionary mutation, Array<Variant>? extraGameStates = null, bool isInlineMutation = false)
        {
            Instance.Call("_bridge_mutate", mutation, extraGameStates ?? new Array<Variant>(), isInlineMutation);
            await Instance.ToSignal(Instance, "bridge_mutated");
        }


        public bool ThingHasMethod(GodotObject thing, string method)
        {
            MethodInfo? info = thing.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);
            return info != null;
        }


    public async void ResolveThingMethod(GodotObject thing, string method, Array<Variant> args)
    {
        MethodInfo? info = thing.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);

        if (info == null) return;

#nullable disable
        // Convert the method args to something reflection can handle
        ParameterInfo[] argTypes = info.GetParameters();
        object[] _args = new object[argTypes.Length];
        for (int i = 0; i < argTypes.Length; i++)
        {
            // check if args is assignable from derived type
            if (i < args.Count && args[i].Obj != null)
            {
                if (argTypes[i].ParameterType.IsAssignableFrom(args[i].Obj.GetType()))
                {
                    _args[i] = args[i].Obj;
                }
                // fallback to assigning primitive types
                else
                {
                    _args[i] = Convert.ChangeType(args[i].Obj, argTypes[i].ParameterType);
                }
            }
            else if (argTypes[i].DefaultValue != null)
            {
                _args[i] = argTypes[i].DefaultValue;
            }
        }

        // Add a single frame wait in case the method returns before signals can listen
        await ToSignal(Engine.GetMainLoop(), SceneTree.SignalName.ProcessFrame);

        // invoke method and handle the result based on return type
        object result = info.Invoke(thing, _args);

        if (result is Task taskResult)
        {
            // await Tasks and handle result if it is a Task<T>
            await taskResult;
            var taskType = taskResult.GetType();
            if (taskType.IsGenericType && taskType.GetGenericTypeDefinition() == typeof(Task<>))
            {
                var resultProperty = taskType.GetProperty("Result");
                var taskResultValue = resultProperty.GetValue(taskResult);
                EmitSignal(SignalName.Resolved, (Variant)taskResultValue);
            }
            else
            {
                EmitSignal(SignalName.Resolved, null);
            }
        }
        else
        {
            EmitSignal(SignalName.Resolved, (Variant)result);
        }
    }
#nullable enable
    }


    public partial class DialogueLine : RefCounted
    {
        private string id = "";
        public string Id
        {
            get => id;
            set => id = value;
        }

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
        public Dictionary Pauses
        {
            get => pauses;
        }

        private Dictionary speeds = new Dictionary();
        public Dictionary Speeds
        {
            get => speeds;
        }

        private Array<Godot.Collections.Array> inline_mutations = new Array<Godot.Collections.Array>();
        public Array<Godot.Collections.Array> InlineMutations
        {
            get => inline_mutations;
        }

        private Array<Variant> extra_game_states = new Array<Variant>();
        public Array<Variant> ExtraGameStates
        {
            get => extra_game_states;
        }

        private Array<string> tags = new Array<string>();
        public Array<string> Tags
        {
            get => tags;
        }

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
            tags = (Array<string>)data.Get("tags");

            foreach (var response in (Array<RefCounted>)data.Get("responses"))
            {
                responses.Add(new DialogueResponse(response));
            }
        }


        public string GetTagValue(string tagName)
        {
            string wrapped = $"{tagName}=";
            foreach (var tag in tags)
            {
                if (tag.StartsWith(wrapped))
                {
                    return tag.Substring(wrapped.Length);
                }
            }
            return "";
        }

        public override string ToString()
        {
            switch (type)
            {
                case "dialogue":
                    return $"<DialogueLine character=\"{character}\" text=\"{text}\">";
                case "mutation":
                    return "<DialogueLine mutation>";
                default:
                    return "";
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

        private Array<string> tags = new Array<string>();
        public Array<string> Tags
        {
            get => tags;
        }

        public DialogueResponse(RefCounted data)
        {
            next_id = (string)data.Get("next_id");
            is_allowed = (bool)data.Get("is_allowed");
            text = (string)data.Get("text");
            translation_key = (string)data.Get("translation_key");
            tags = (Array<string>)data.Get("tags");
        }

        public string GetTagValue(string tagName)
        {
            string wrapped = $"{tagName}=";
            foreach (var tag in tags)
            {
                if (tag.StartsWith(wrapped))
                {
                    return tag.Substring(wrapped.Length);
                }
            }
            return "";
        }

        public override string ToString()
        {
            return $"<DialogueResponse text=\"{text}\"";
        }
    }
}


using Godot;

namespace DialogueManagerRuntime
{
    /// <summary>
    /// Add a <see cref="DialogueStateContext"/> to a scene to expose a node (usually the base node) to dialogue.
    /// </summary>
    [Tool, Icon("uid://c22t5famre1yo")]
    public partial class DialogueStateContext : Node
    {
        private string alias = "";

        /// <summary>
        /// The name used in dialogue to refer to the exposed target node.
        /// </summary>
        [Export]
        public string Alias
        {
            get => alias;
            set
            {
                alias = value;
                UpdateConfigurationWarnings();
            }
        }

        private Node target = null;

        /// <summary>
        /// The target whose values are exposed to dialogue.
        /// </summary>
        [Export]
        public Node Target
        {
            get => target;
            set
            {
                target = value;
                UpdateConfigurationWarnings();
            }
        }


        public override void _EnterTree()
        {
            if (Engine.IsEditorHint()) return;

            GodotObject dialogueManager = GetDialogueManager();
            if (dialogueManager is not null)
            {
                // Register straight away in case some dialogue starts on this same frame.
                dialogueManager.Call("register_state_context", Alias, Target);
            }
            else
            {
                // The DialogueManager autoload isn't in the tree yet (this node is probably inside
                // an autoload that comes before it) so register as soon as it is.
                Callable.From(() =>
                {
                    GetDialogueManager()?.Call("register_state_context", Alias, Target);
                }).CallDeferred();
            }
        }


        public override void _ExitTree()
        {
            if (Engine.IsEditorHint()) return;

            GetDialogueManager()?.Call("unregister_state_context", Alias);
        }


        public override string[] _GetConfigurationWarnings()
        {
            var warnings = new System.Collections.Generic.List<string>();

            if (string.IsNullOrEmpty(Alias))
            {
                warnings.Add("Alias cannot be empty.");
            }

            if (Target == null)
            {
                warnings.Add("Target cannot be null.");
            }

            return [.. warnings];
        }


        /// <summary>
        /// Find the DialogueManager autoload. It registers itself as a singleton in its "_ready" so
        /// it might need to be fetched out of the scene tree if it hasn't gotten there yet.
        /// </summary>
        private static GodotObject GetDialogueManager()
        {
            if (Engine.HasSingleton("DialogueManager")) return DialogueManager.Instance;

            return (Engine.GetMainLoop() as SceneTree)?.Root.GetNodeOrNull("DialogueManager");
        }
    }
}

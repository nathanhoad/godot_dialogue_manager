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
            if (!Engine.IsEditorHint())
            {
                DialogueManager.Instance.Call("register_state_context", Alias, Target);
            }
        }


        public override void _ExitTree()
        {
            if (!Engine.IsEditorHint())
            {
                DialogueManager.Instance.Call("unregister_state_context", Alias);
            }
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

            return warnings.ToArray();
        }
    }
}

using Godot;
using Godot.Collections;
using System;

namespace DialogueManagerRuntime
{
    /// <summary>
    /// A special <see cref="Area3D"/> node to hold information about starting dialogue.
    ///
    /// Assuming <c>DialogueResource</c> and <c>DialogueCue</c> have been configured you can
    /// call <c>Action()</c> on this node at runtime to start dialogue.
    /// </summary>
    [Tool, Icon("uid://dppsuhlvbcbjc")]
    public partial class DialogueActionable3D : Area3D
    {
        /// <summary>
        /// Emitted when this <see cref="DialogueActionable3D"/> has <c>Action()</c> called on it.
        /// </summary>
        [Signal] public delegate void ActionedEventHandler();

        /// <summary>
        /// Emitted when the dialogue resource associated with this <see cref="DialogueActionable3D"/> ends. NOTE: The
        /// signal is also emitted if the same resource is used for multiple <see cref="DialogueActionable3D"/> nodes in the tree.
        /// </summary>
        [Signal] public delegate void DialogueEndedEventHandler();


        private Resource dialogueResource = null;

        /// <summary>
        /// The dialogue resource to use when starting dialogue.
        /// </summary>
        [Export]
        public Resource DialogueResource
        {
            get => dialogueResource;
            set
            {
                dialogueResource = value;
                if (dialogueResource == null)
                {
                    DialogueCue = "";
                }
                NotifyPropertyListChanged();
            }
        }

        /// <summary>
        /// The target cue to start dialogue from.
        /// </summary>
        [Export] public string DialogueCue = "";

        /// <summary>
        /// The dialogue balloon that was last used by calling <c>Action()</c> (if there was one).
        /// </summary>
        public Node DialogueBalloon;

        /// <summary>
        /// The method used to start dialogue when <c>Action()</c> is called. Override if you need different logic.
        /// </summary>
        public static Func<Resource, string, Array<Variant>, Node> StartDialogue = (withDialogueResource, fromCue, extraGameStates) =>
            DialogueManager.ShowDialogueBalloon(withDialogueResource, fromCue, extraGameStates);


        public override void _Ready()
        {
            if (!Engine.IsEditorHint())
            {
                AddToGroup("dialogue_actionables");
                // Touch the instance to make sure the DialogueManager bridge signals are connected
                _ = DialogueManager.Instance;
                DialogueManager.DialogueEnded += OnDialogueEnded;
            }
        }


        public override void _ExitTree()
        {
            if (!Engine.IsEditorHint())
            {
                DialogueManager.DialogueEnded -= OnDialogueEnded;
            }
        }


        #region Public


        /// <summary>
        /// Action this <see cref="DialogueActionable3D"/>. If a dialogue resource and cue have been set on this node then it will start dialogue.
        /// </summary>
        public void Action()
        {
            if (IsInstanceValid(DialogueResource) && !string.IsNullOrEmpty(DialogueCue))
            {
                DialogueBalloon = StartDialogue(DialogueResource, DialogueCue, new Array<Variant> { new Dictionary { { "actionable", this } }, Owner });
            }
            EmitSignal(SignalName.Actioned);
        }


        /// <summary>
        /// Find the nearest <see cref="DialogueActionable3D"/> to a given position.
        /// </summary>
        public static DialogueActionable3D GetNearestActionableTo(Vector3 targetPosition)
        {
            float nearestDistance = float.PositiveInfinity;
            DialogueActionable3D nearestActionable = null;
            foreach (Node node in ((SceneTree)Engine.GetMainLoop()).GetNodesInGroup("dialogue_actionables"))
            {
                if (node is not DialogueActionable3D actionable) continue;

                float distance = actionable.GlobalPosition.DistanceSquaredTo(targetPosition);
                if (distance < nearestDistance)
                {
                    nearestDistance = distance;
                    nearestActionable = actionable;
                }
            }

            return nearestActionable;
        }


        #endregion

        #region Signals


        private void OnDialogueEnded(Resource endingDialogueResource)
        {
            if (endingDialogueResource == DialogueResource)
            {
                EmitSignal(SignalName.DialogueEnded);
            }
        }


        #endregion
    }
}

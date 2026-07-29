using Godot;
using Godot.Collections;

namespace DialogueManagerRuntime
{
    /// <summary>
    /// A special marker node that helps locate the in-world representation of the speaking character.
    /// Generally, you would position a <see cref="DialogueMarker2D"/> at the mouth of the character and use
    /// its location as the origin of a speech balloon.
    /// </summary>
    [Icon("uid://cim0y62o6g36i")]
    public partial class DialogueMarker2D : Marker2D
    {
        /// <summary>
        /// The name of the character that owns this marker.
        /// </summary>
        [Export] public string CharacterName = "";


        #region Static


        /// <summary>
        /// Get all <see cref="DialogueMarker2D"/> nodes.
        /// </summary>
        public static Array<DialogueMarker2D> All()
        {
            var markers = new Array<DialogueMarker2D>();
            foreach (Node node in ((SceneTree)Engine.GetMainLoop()).GetNodesInGroup("2d_dialogue_markers"))
            {
                if (node is DialogueMarker2D marker)
                {
                    markers.Add(marker);
                }
            }
            return markers;
        }


        /// <summary>
        /// Find a marker with a given character name.
        /// </summary>
        public static DialogueMarker2D FindForCharacter(string targetCharacterName)
        {
            foreach (DialogueMarker2D marker in All())
            {
                if (marker.CharacterName == targetCharacterName)
                {
                    return marker;
                }
            }
            return null;
        }


        #endregion


        public override void _Ready()
        {
            AddToGroup("2d_dialogue_markers");
        }


        #region Helpers


        /// <summary>
        /// Get the marker's position relative to the viewport.
        /// </summary>
        public Vector2 GetPositionInViewport()
        {
            return GetGlobalTransformWithCanvas().Origin;
        }


        #endregion
    }
}

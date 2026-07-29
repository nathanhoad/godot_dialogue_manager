using Godot;
using Godot.Collections;

namespace DialogueManagerRuntime
{
    /// <summary>
    /// A special marker node that helps locate the in-world representation of the speaking character.
    /// Generally, you would position a <see cref="DialogueMarker3D"/> at the mouth of the character and use
    /// its location as the origin of a speech balloon.
    /// </summary>
    [Icon("uid://bo1hdyjmnjdql")]
    public partial class DialogueMarker3D : Marker3D
    {
        /// <summary>
        /// The name of the character that owns this marker.
        /// </summary>
        [Export] public string CharacterName = "";


        #region Static


        /// <summary>
        /// Get all <see cref="DialogueMarker3D"/> nodes.
        /// </summary>
        public static Array<DialogueMarker3D> All()
        {
            var markers = new Array<DialogueMarker3D>();
            foreach (Node node in ((SceneTree)Engine.GetMainLoop()).GetNodesInGroup("3d_dialogue_markers"))
            {
                if (node is DialogueMarker3D marker)
                {
                    markers.Add(marker);
                }
            }
            return markers;
        }


        /// <summary>
        /// Find a marker with a given character name.
        /// </summary>
        public static DialogueMarker3D FindForCharacter(string targetCharacterName)
        {
            foreach (DialogueMarker3D marker in All())
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
            AddToGroup("3d_dialogue_markers");
        }


        #region Helpers


        /// <summary>
        /// Get the marker's position relative to the viewport.
        /// </summary>
        public Vector2 GetPositionInViewport()
        {
            Camera3D camera = GetViewport().GetCamera3D();
            if (IsInstanceValid(camera))
            {
                return camera.UnprojectPosition(GlobalPosition);
            }
            else
            {
                return Vector2.Zero;
            }
        }


        #endregion
    }
}

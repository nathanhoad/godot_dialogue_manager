using Godot;
using Godot.Collections;

namespace DialogueManagerRuntime
{
    /// <summary>
    /// A <see cref="Container"/> for dialogue responses provided by Dialogue Manager.
    /// </summary>
    public partial class DialogueResponsesMenu : Container
    {
        /// <summary>
        /// Emitted when a response is focused.
        /// </summary>
        [Signal] public delegate void ResponseFocusedEventHandler(Variant response);

        /// <summary>
        /// Emitted when a response is selected.
        /// </summary>
        [Signal] public delegate void ResponseSelectedEventHandler(DialogueResponse response);


        /// <summary>
        /// Optionally specify a control to duplicate for each response.
        /// </summary>
        [Export] public Control ResponseTemplate;

        /// <summary>
        /// The action for accepting a response (is possibly overridden by parent dialogue balloon).
        /// </summary>
        [Export] public StringName NextAction = "";

        /// <summary>
        /// Automatically set up focus neighbours when the responses list changes.
        /// </summary>
        [Export] public bool AutoConfigureFocus = true;

        /// <summary>
        /// Automatically focus the first item when showing.
        /// </summary>
        [Export] public bool AutoFocusFirstItem = true;

        /// <summary>
        /// Hide any responses where <c>IsAllowed</c> is false.
        /// </summary>
        [Export] public bool HideFailedResponses = false;

        private Godot.Collections.Array<DialogueResponse> responses = new();

        /// <summary>
        /// The list of dialogue responses.
        /// </summary>
        public Godot.Collections.Array<DialogueResponse> Responses
        {
            get => responses;
            set
            {
                responses = value;
                ApplyResponses();
            }
        }

        // The previously focused item in this menu.
        private Control previouslyFocusedItem = null;


        public override void _Ready()
        {
            VisibilityChanged += () =>
            {
                if (AutoFocusFirstItem && Visible && GetMenuItems().Count > 0)
                {
                    Control firstItem = GetMenuItems()[0];
                    if (firstItem.IsInsideTree())
                    {
                        firstItem.GrabFocus();
                    }
                }
            };

            if (IsInstanceValid(ResponseTemplate))
            {
                ResponseTemplate.Hide();
            }

            GetViewport().GuiFocusChanged += OnFocusChanged;
        }


        public override void _ExitTree()
        {
            GetViewport().GuiFocusChanged -= OnFocusChanged;
        }


        /// <summary>
        /// Get the selectable items in the menu.
        /// </summary>
        public Array<Control> GetMenuItems()
        {
            var items = new Array<Control>();
            foreach (Node child in GetChildren())
            {
                if (child is not Control control) continue;
                if (!control.Visible) continue;
                if (control.Name.ToString().Contains("Disallowed")) continue;
                items.Add(control);
            }

            return items;
        }


        /// <summary>
        /// Prepare the menu for keyboard and mouse navigation.
        /// </summary>
        public void ConfigureFocus()
        {
            Array<Control> items = GetMenuItems();
            for (int i = 0; i < items.Count; i++)
            {
                Control item = items[i];

                item.FocusMode = FocusModeEnum.All;

                item.FocusNeighborLeft = item.GetPath();
                item.FocusNeighborRight = item.GetPath();

                if (i == 0)
                {
                    item.FocusNeighborTop = item.GetPath();
                    item.FocusNeighborLeft = item.GetPath();
                    item.FocusPrevious = item.GetPath();
                }
                else
                {
                    item.FocusNeighborTop = items[i - 1].GetPath();
                    item.FocusNeighborLeft = items[i - 1].GetPath();
                    item.FocusPrevious = items[i - 1].GetPath();
                }

                if (i == items.Count - 1)
                {
                    item.FocusNeighborBottom = item.GetPath();
                    item.FocusNeighborRight = item.GetPath();
                    item.FocusNext = item.GetPath();
                }
                else
                {
                    item.FocusNeighborBottom = items[i + 1].GetPath();
                    item.FocusNeighborRight = items[i + 1].GetPath();
                    item.FocusNext = items[i + 1].GetPath();
                }

                DialogueResponse response = (DialogueResponse)item.GetMeta("response");
                item.MouseEntered += () => OnResponseMouseEntered(item);
                item.GuiInput += (@event) => OnResponseGuiInput(@event, item, response);
            }

            if (items.Count == 0) return;

            previouslyFocusedItem = items[0];

            if (AutoFocusFirstItem)
            {
                items[0].GrabFocus();
            }
        }


        #region Internal


        // Set up the visual side of things.
        private void ApplyResponses()
        {
            // Remove any current items
            foreach (Node item in GetChildren())
            {
                if (item == ResponseTemplate) continue;

                RemoveChild(item);
                item.QueueFree();
            }

            // Add new items
            if (responses.Count > 0)
            {
                foreach (DialogueResponse response in responses)
                {
                    // The response might be tagged with "show_if"
                    if (HideFailedResponses && !response.IsAllowed && response.GetTagValue("show_if") != "true")
                    {
                        continue;
                    }

                    if (response.GetTagValue("hide_if") == "true")
                    {
                        continue;
                    }

                    Control item;
                    if (IsInstanceValid(ResponseTemplate))
                    {
                        item = (Control)ResponseTemplate.Duplicate((int)(DuplicateFlags.Groups | DuplicateFlags.Scripts | DuplicateFlags.Signals));
                        item.Show();
                    }
                    else
                    {
                        item = new Button();
                    }
                    item.Name = $"Response{GetChildCount()}";
                    if (!response.IsAllowed)
                    {
                        item.Name = $"{item.Name}Disallowed";
                        item.Set("disabled", true);
                    }

                    // If the item has a response property then use that
                    string responsePropertyName = GetResponsePropertyName(item);
                    if (responsePropertyName != null)
                    {
                        item.Set(responsePropertyName, response);
                    }
                    // Otherwise assume we can just set the text
                    else
                    {
                        item.Set("text", response.Text);
                    }

                    item.SetMeta("response", response);

                    AddChild(item);
                }

                if (AutoConfigureFocus)
                {
                    ConfigureFocus();
                }
            }
        }


        // Find the name of the item's "response" property (if it has one).
        private static string GetResponsePropertyName(Control item)
        {
            foreach (Dictionary property in item.GetPropertyList())
            {
                string name = (string)property["name"];
                if (name == "response" || name == "Response")
                {
                    return name;
                }
            }
            return null;
        }


        #endregion

        #region Signals


        private void OnFocusChanged(Control control)
        {
            if (control.Name.ToString().Contains("Disallowed")) return;
            if (!GetMenuItems().Contains(control)) return;

            if (previouslyFocusedItem != control)
            {
                previouslyFocusedItem = control;
                EmitSignal(SignalName.ResponseFocused, control);
            }
        }


        private void OnResponseMouseEntered(Control item)
        {
            if (item.Name.ToString().Contains("Disallowed")) return;

            item.GrabFocus();
        }


        private void OnResponseGuiInput(InputEvent @event, Control item, DialogueResponse response)
        {
            if (item.Name.ToString().Contains("Disallowed")) return;

            if (@event is InputEventMouseButton mouseButtonEvent && mouseButtonEvent.IsPressed() && mouseButtonEvent.ButtonIndex == MouseButton.Left)
            {
                GetViewport().SetInputAsHandled();
                EmitSignal(SignalName.ResponseSelected, response);
            }
            else if (@event.IsActionPressed(NextAction.IsEmpty ? "ui_accept" : NextAction) && GetMenuItems().Contains(item))
            {
                GetViewport().SetInputAsHandled();
                EmitSignal(SignalName.ResponseSelected, response);
            }
        }


        #endregion
    }
}

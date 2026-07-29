using Godot;
using System.Globalization;
using System.Threading.Tasks;

namespace DialogueManagerRuntime
{
    /// <summary>
    /// A RichTextLabel specifically for use with Dialogue Manager dialogue.
    /// </summary>
    [Tool, Icon("uid://s0s1348tpm6d")]
    public partial class DialogueLabel : RichTextLabel
    {
        /// <summary>
        /// Emitted for each letter typed out.
        /// </summary>
        [Signal] public delegate void SpokeEventHandler(string letter, int letterIndex, float speed);

        /// <summary>
        /// Emitted when the player skips the typing of dialogue.
        /// </summary>
        [Signal] public delegate void SkippedTypingEventHandler();

        /// <summary>
        /// Emitted when typing starts.
        /// </summary>
        [Signal] public delegate void StartedTypingEventHandler();

        /// <summary>
        /// Emitted when typing finishes.
        /// </summary>
        [Signal] public delegate void FinishedTypingEventHandler();


        /// <summary>
        /// The action to press to skip typing.
        /// </summary>
        [Export] public StringName SkipAction = "ui_cancel";

        /// <summary>
        /// The speed with which the text types out.
        /// </summary>
        [Export] public float SecondsPerStep = 0.02f;

        /// <summary>
        /// Automatically have a brief pause when these characters are encountered.
        /// </summary>
        [Export] public string PauseAtCharacters = ".?!";

        /// <summary>
        /// Don't auto pause if the character after the pause is one of these.
        /// </summary>
        [Export] public string SkipPauseAtCharacterIfFollowedBy = ")\"";

        /// <summary>
        /// Don't auto pause after these abbreviations (only if "." is in <c>PauseAtCharacters</c>).
        /// Abbreviations are limited to 5 characters in length.
        /// Does not support multi-period abbreviations (ex. "p.m.")
        /// </summary>
        [Export] public string[] SkipPauseAtAbbreviations = { "Mr", "Mrs", "Ms", "Dr", "etc", "eg", "ex" };

        /// <summary>
        /// The amount of time to pause when exposing a character present in <c>PauseAtCharacters</c>.
        /// </summary>
        [Export] public float SecondsPerPauseStep = 0.3f;

        private readonly System.Collections.Generic.List<int> alreadyMutatedIndices = new();


        private DialogueLine dialogueLine = null;

        /// <summary>
        /// The current line of dialogue.
        /// </summary>
        public DialogueLine DialogueLine
        {
            get => dialogueLine;
            set
            {
                if (value != dialogueLine)
                {
                    dialogueLine = value;
                    UpdateText();
                }
            }
        }

        /// <summary>
        /// Whether the label is currently typing itself out.
        /// </summary>
        public bool IsTyping
        {
            get => isTyping && !isAwaitingMutation;
            set
            {
                bool didJustFinish = isTyping != value && value == false && VisibleCharacters == GetTotalCharacterCount();
                isTyping = value;
                if (didJustFinish)
                {
                    EmitSignal(SignalName.FinishedTyping);
                }
            }
        }
        private bool isTyping = false;

        private int lastWaitIndex = -1;
        private int lastMutationIndex = -1;
        private float waitingSeconds = 0;
        private bool isAwaitingMutation = false;
        private bool isSkippingMutations = false;


        public override void _Process(double delta)
        {
            if (isTyping)
            {
                // Type out text
                if (VisibleRatio < 1)
                {
                    // See if we are waiting
                    if (waitingSeconds > 0)
                    {
                        waitingSeconds -= (float)delta;
                    }
                    // If we are no longer waiting then keep typing
                    if (waitingSeconds <= 0)
                    {
                        TypeNext((float)delta, waitingSeconds);
                    }
                }
                else
                {
                    // Make sure any mutations at the end of the line get run
                    _ = MutateInlineMutations(GetTotalCharacterCount());
                    IsTyping = false;
                }
            }
        }


        /// <summary>
        /// Sets the label's text from the current dialogue line. Override if you want
        /// to do something more interesting in your subclass.
        /// </summary>
        protected virtual void UpdateText()
        {
            if (IsInstanceValid(dialogueLine))
            {
                Text = dialogueLine.Text;
            }
            else
            {
                Text = "";
            }
        }


        /// <summary>
        /// Start typing out the text.
        /// </summary>
        public async void TypeOut()
        {
            UpdateText();
            VisibleCharacters = 0;
            VisibleRatio = 0;
            waitingSeconds = 0;
            lastWaitIndex = -1;
            lastMutationIndex = -1;
            alreadyMutatedIndices.Clear();

            IsTyping = true;
            EmitSignal(SignalName.StartedTyping);

            // Allow typing listeners a chance to connect
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

            if (GetTotalCharacterCount() == 0)
            {
                IsTyping = false;
            }
            else if (SecondsPerStep == 0)
            {
                MutateRemainingMutations();
                VisibleCharacters = GetTotalCharacterCount();
                IsTyping = false;
            }
        }


        /// <summary>
        /// Stop typing out the text and jump right to the end.
        /// </summary>
        public void SkipTyping()
        {
            MutateRemainingMutations();
            VisibleCharacters = GetTotalCharacterCount();
            IsTyping = false;
            EmitSignal(SignalName.SkippedTyping);
        }


        // Type out the next character(s)
        private void TypeNext(float delta, float secondsNeeded)
        {
            if (isAwaitingMutation) return;

            if (VisibleCharacters == GetTotalCharacterCount())
            {
                return;
            }

            if (lastMutationIndex != VisibleCharacters)
            {
                lastMutationIndex = VisibleCharacters;
                _ = MutateInlineMutations(VisibleCharacters);
                if (isAwaitingMutation) return;
            }

            // Pause on characters like "."
            float pauseWaitingSeconds = ShouldAutoPause() ? SecondsPerPauseStep : 0f;
            if (lastWaitIndex != VisibleCharacters && pauseWaitingSeconds > 0)
            {
                lastWaitIndex = VisibleCharacters;
                waitingSeconds += pauseWaitingSeconds;
            }
            else
            {
                VisibleCharacters += 1;
                if (VisibleCharacters <= GetTotalCharacterCount())
                {
                    EmitSignal(SignalName.Spoke, GetParsedText()[VisibleCharacters - 1].ToString(), VisibleCharacters - 1, GetSpeed(VisibleCharacters));
                }
                // See if there's time to type out some more in this frame
                secondsNeeded += SecondsPerStep * (1.0f / GetSpeed(VisibleCharacters));
                if (secondsNeeded > delta)
                {
                    waitingSeconds += secondsNeeded;
                }
                else
                {
                    TypeNext(delta, secondsNeeded);
                }
            }
        }


        // Get the speed for the current typing position
        private float GetSpeed(int atIndex)
        {
            float speed = 1;
            foreach (var speedEntry in dialogueLine.Speeds)
            {
                if ((int)speedEntry.Key > atIndex)
                {
                    return speed;
                }
                speed = (float)speedEntry.Value;
            }
            return speed;
        }


        // Run any inline mutations that haven't been run yet
        private void MutateRemainingMutations()
        {
            isSkippingMutations = true;
            for (int i = VisibleCharacters; i < GetTotalCharacterCount() + 1; i++)
            {
                _ = MutateInlineMutations(i);
            }
            isSkippingMutations = false;
        }


        // Run any mutations at the current typing position
        private async Task MutateInlineMutations(int index)
        {
            if (!IsInstanceValid(dialogueLine)) return;

            foreach (Godot.Collections.Array inlineMutation in dialogueLine.InlineMutations)
            {
                // Inline mutations are an array of arrays in the form of [character index, resolvable function]
                if ((int)inlineMutation[0] > index)
                {
                    return;
                }
                if ((int)inlineMutation[0] == index && !alreadyMutatedIndices.Contains(index))
                {
                    if (isSkippingMutations)
                    {
                        _ = DialogueManager.Mutate(inlineMutation[1].AsGodotDictionary(), dialogueLine.ExtraGameStates, true);
                    }
                    else
                    {
                        isAwaitingMutation = true;
                        await DialogueManager.Mutate(inlineMutation[1].AsGodotDictionary(), dialogueLine.ExtraGameStates, true);
                        isAwaitingMutation = false;
                    }
                }
            }

            alreadyMutatedIndices.Add(index);
        }


        // Determine if the current autopause character at the cursor should qualify to pause typing.
        private bool ShouldAutoPause()
        {
            if (VisibleCharacters == 0) return false;

            string parsedText = GetParsedText();

            // Avoid out-of-bounds when the label auto-translates and the text changes to one shorter while typing out
            // Note: visible characters can be larger than parsed_text after a translation event
            if (VisibleCharacters >= parsedText.Length) return false;

            // Ignore pause characters if they are next to a non-pause character
            if (SkipPauseAtCharacterIfFollowedBy.Contains(parsedText[VisibleCharacters]))
            {
                return false;
            }

            // Ignore "." if it's between two numbers
            if (VisibleCharacters > 3 && parsedText[VisibleCharacters - 1] == '.')
            {
                string possibleNumber = parsedText.Substring(VisibleCharacters - 2, 3);
                if (float.TryParse(possibleNumber, NumberStyles.Float, CultureInfo.InvariantCulture, out float number) && number.ToString("0.0", CultureInfo.InvariantCulture) == possibleNumber)
                {
                    return false;
                }
            }

            // Ignore "." if it's used in an abbreviation
            // Note: does NOT support multi-period abbreviations (ex. p.m.)
            if (PauseAtCharacters.Contains('.') && parsedText[VisibleCharacters - 1] == '.')
            {
                foreach (string abbreviation in SkipPauseAtAbbreviations)
                {
                    int start = VisibleCharacters - abbreviation.Length - 1;
                    if (VisibleCharacters >= abbreviation.Length && start >= 0 && parsedText.Substring(start, abbreviation.Length) == abbreviation)
                    {
                        return false;
                    }
                }
            }

            // Ignore two non-"." characters next to each other
            string otherPauseCharacters = PauseAtCharacters.Replace(".", "");
            if (VisibleCharacters > 1 && otherPauseCharacters.Contains(parsedText[VisibleCharacters - 1]) && otherPauseCharacters.Contains(parsedText[VisibleCharacters]))
            {
                return false;
            }

            return PauseAtCharacters.Contains(parsedText[VisibleCharacters - 1]);
        }
    }
}

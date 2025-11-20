# Local Variables

The `locals` property gives you access to dialogue-session-specific variables. These variables are created when dialogue starts, or in the middle of the conversation, and deleted the moment the conversation ends.

Local variables are useful for:

- Tracking temporary dialogue state (e.g., choices made during the current conversation)
- Counting things within a dialogue session
- Storing intermediate values without polluting your global script.

## Creating local variables

You can work with local variables in two main ways:

### 1. Passing extra game states

You can pass a dictionary as extra game state when starting a dialogue. This makes its contents available to the dialogue while it runs.

```gdscript
# In your game code
var player_stats = {"level": 10, "health": 100}
DialogueManager.start(load("res://conversation.dialogue"), "start", [player_stats])
```

In your dialogue, you can reference these directly:

```
~ start
if level >= 10:
	Nathan: Wow, level {{level}}! You've come a long way.

Nathan: Your health is at {{health}}.
```

### 2. Setting locals within dialogue

You can create and modify local variables directly in your dialogue file using `set` or `do`:

```
~ start
Nathan: Let me count to three.
set locals.counter = 1
Nathan: {{locals.counter}}
do locals.counter += 1
Nathan: {{locals.counter}}
do locals.counter += 1
Nathan: {{locals.counter}}
Nathan: Done!
=> END
```

In this example, the `locals.counter` is created when it's first assigned and persists throughout the conversation. Once the dialogue ends, this variable will be discarded.


### Locals vs Extra game states

Extra game states are NOT locals, but they are similar, since they only exist in the scope of the current conversation.
You can NOT access Extra Game states using `locals.state_name = 5`, nor you can access a variable you created using locals just by using:
`state_name = "Nathan"`. You need to add the `locals` prefix.

## Examples

The following examples show common ways to use locals in real dialogue files.

### Local variables in conditions

You can use local variables in conditions like any other variable.

```
~ start
set locals.player_response = ""
Nathan: Do you like programming?

- Yes
	set locals.player_response = "yes"

- No
	set locals.player_response = "no"

if locals.player_response == "yes"
	Nathan: That's great! Me too!
else
	Nathan: Oh, that's okay. Not everyone does.
=> END
```

### Local variables in branching conversations

They can also be useful for tracking which topics have been discussed in branching conversations:

```
~ start
Nathan: What would you like to know?

- Tell me about yourself [if not locals.asked_about_nathan]
	set locals.asked_about_nathan = true
	Nathan: Well, I'm a game developer who loves making dialogue systems.
	=> start

- What's your favorite color? [if not locals.asked_favorite_color]
	set locals.asked_favorite_color = true
	Nathan: I'd say blue. It's calming.
	=> start

- That's all for now
	Nathan: Alright, see you around!
	=> END
```

### Local variables in loops

Local variables are also useful in `while` loops:

```
~ start
set locals.countdown = 3
Nathan: Starting countdown...

while locals.countdown > 0
	Nathan: {{locals.countdown}}!
	do locals.countdown -= 1

Nathan: Countdown is over.
=> END
```

### Example: Number guessing game

This example shows a number guessing game:

```
~ start
set locals.secret_number = 2
set locals.attempts = 0
Nathan: I'm thinking of a number between 1 and 3.
=> guess


~ guess
Nathan: What's your guess?
- 1
	set locals.guess = 1
	=> check_answer
- 2
	set locals.guess = 2
	=> check_answer
- 3
	set locals.guess = 3
	=> check_answer


~ check_answer
do locals.attempts += 1

if locals.attempts == 2
	Nathan: You've used all your attempts! The number was {{locals.secret_number}}.
	=> END
elif locals.guess == locals.secret_number
	if locals.attempts == 1:
		Nathan: You got it in {{locals.attempts}} attempt!
	else
		Nathan: You got it in {{locals.attempts}} attempts!
	=> END
else
	Nathan: Nope! Try again.
	=> guess
```

## Local vs Global

**Use local when:**
- The data only matters during the current conversation
- You are tracking choices or branches within a dialogue
- You are prototyping and don't want to commit to permanent variables yet

**Use Global variables when:**
- The data needs to persist between conversations
- Multiple systems in your game need to access it
- It represents core game progression or player statistics
- It should be saved with the game

# State

The Dialogue Manager runtime is stateless. What that means is your game is the authority of any game state and Dialogue Manager defers to your game in order to read and write that state.

There are a bunch of ways to expose your game state to dialogue.

- **Globals** - The simplest is autoloads. Any globals defined in Godot's autoloads will be available to dialogue directly.
- **DialogueStateContext Nodes** - Add `DialogueStateContext` nodes to a scene to make it available whenever that node exists in the current scene tree.
- **extra_game_states** - The last resort is usually passing an array of extra nodes or dictionaries to `get_next_dialogue_line` that contain more state. This approach is the most brittle.

To see which context nodes and globals are currently available at runtime, you can check in the "Dialogue" tab in the debugger. This also shows a history of each dialogue line that has been run.

## DialogueStateContext Nodes

You can add a `DialogueStateContext` node to any scene in the scene tree, give an alias, and point it at another node.

Whenever that context node is in the current scene tree it will make it's target available via the alias.

For example, if you have your player character scene and add a `DialogueStateContext` node, you can give it an alias of "player" and set it's target to be the base node of the tree (the `CharacterBody2D` or whatever). Now, whenever your player is in the running root scene tree it can be referred to within dialogue as `player` and it's defined properties and methods are available as mutations.

```
if player.health > 10
    Someone: Wow, you are at full health!
```

## Conditions & Mutations

Once you have some state hooked up you can start using conditions in branches and dialogue, and running mutations to affect state.

See [Conditions & Mutations](./Conditions_Mutations.md).


## Variables in dialogue

To show some value of game state within a line of dialogue, wrap it in double curlies.

```
Nathan: The value of some property is {{some_node_in_scope.some_property}}.
```

Similarly, if the name of a character is based on a variable you can provide it in double curlies too:

```
{{SomeGlobal.some_character_name}}: My name was provided by the player.
```

### Local variables

If you need temporary variables that only exist during a dialogue conversation, you can use locals. Locals are temporary variables that only live for the current conversation. When the conversation ends or changes dialogue files, the variables are deleted.

_Note: `locals` is a feature provided by the example balloon as a demonstration of handling temporary state, not a built-in feature of Dialogue Manager itself._

You can create local variables in two ways:

1. **Setting them within dialogue** using mutations:

```
~start
Nathan: What would you like to know?

- Tell me about yourself [if not locals.asked_about_nathan /]
    $> locals.asked_about_nathan = true
    Nathan: Well, I'm a game developer who loves making dialogue systems.
    => start

- What's your favorite color? [if not locals.asked_favorite_color /]
    $> locals.asked_favorite_color = true
    Nathan: I'd say blue. It's calming.
    => start

- That's all for now
    Nathan: Alright, see you around!
    => END
```

2. **Passing extra game states** when starting dialogue (see [Extra Game States](./Conditions_Mutations.md#extra-game-states) for details). Variables from extra game states can be referenced directly without the `locals.` prefix.

### Expression Jumps

You can use expressions as jump directives. The expression needs to resolve to a known cue name or results will be unexpected.

**Use these with caution** as the dialogue compiler can't verify expression values match any cues at compile time.

Expression jumps look something like:

`=> {{SomeGlobal.some_property}}`
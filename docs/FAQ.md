# Frequently Asked Questions

## How can I get help?

You can [ask on my Discord](https://nathanhoad.net/discord), [ask me on Mastodon](https://mastodon.social/@nathanhoad), or [open a discussion on GitHub](https://github.com/nathanhoad/godot_dialogue_manager/discussions).

If you run into something that you think might be a bug then you can [open an issue](https://github.com/nathanhoad/godot_dialogue_manager/issues) (make sure to include your Godot version and Dialogue Manager version).

## How can I support this project?

There are a few ways you can support the development of Dialogue Manager. You can [become a patron on Patreon](https://patreon.com/nathanhoad) or [sponser me on GitHub](https://github.com/sponsors/nathanhoad).

If you're not in a position to do either of those things then you can just [give me a sub or like on YouTube](https://youtube.com/@nathan_hoad).

## How do I stop my player from moving while dialogue is showing?

One of the most common causes is that you've implemented player movement inside `_process` instead of in `_unhandled_input`.

For more of a guide then check out the code for my [beginner dialogue example project](https://github.com/nathanhoad/beginner_godot4_dialogue/blob/finished/characters/coco/coco.gd#L17) and [the video that goes with it](https://youtu.be/UhPFk8FSbd8).

## How do I detect when dialogue has finished?

You can connect to the `DialogueManager.dialogue_ended(resource)` signal. The `resource` parameter is the `DialogueResource` that was used to start the dialogue chain.

## How do I make the example balloon look more like my game?

There is a **Project > Tools** menu option to create a copy of the example balloon into somewhere in your project (never edit the original example balloon directly because any changes you make will be overwritten when updating the addon).

From there it becomes an exercise in UI building using mostly Godot's UI control nodes (with the exception of the provided `DialogueLabel` and `DialogueResponsesMenu` nodes). I recommend digging through the initial code to familiarise yourself with how it works before changing anything.

The most common changes will be to the `theme` that is attached to the `Balloon` panel.

## How do I credit Dialogue Manager in my game?

To comply with the license you just need to include the license text (or a link to it) somewhere in your game, usually at the end of the credits.

If you want to also credit it specifically then you can include something like "Dialogue System by Nathan Hoad" or whatever (I'm not fussy).

## Why isn't something like Dialogue Manager built into Godot?

The short answer is that not all games need to have any kind of dialogue, let alone branching dialogue trees so it would just be introducing bloat into the engine for little benefit. Another good reason to have it as an addon means I can iterate on it much faster than having to wait for engine releases.

# Example Balloons

It's up to you to implement the actual dialogue rendering and input control but there are a few example balloons included in the repository to get you started.

You can find them in the [/examples](../examples) directory. If you want to try out these examples yourself, you'll need to clone the repository, not just download it.

Example scenes include:

- A portrait balloon showing character potraits and typing noises. This also shows using a low res balloon if the viewport is set to lower than 400px.
- Using a mutation to ask the player for their name.
- A Point n Click Adventure style interaction that includes voice acting in multiple languages.
- A Visual Novel style balloon with various character slots and mutations for adding/removing characters in the conversation.
- A C# Balloon that show how you might write a custom balloon in C#.

To see an example in action, open the scenes in [/examples/test_scenes](../examples/test_scenes/) and run them.

If you want to run the Point n Click example in German then you will need to open Project Settings and change _Internationalization/Locale/Test_ to be `"de"` (you might need to enable Advanced Settings to see this).

## Copying the example balloon

There is a "Create copy of example dialogue balloon..." item in the _Project > Tools_ menu. When you click it you will be prompted to choose a directory to save the copied files into. From there, you can edit the new balloon to make it your own.

The most common thing you might want to do is adjust the font and margin sizes and the simplest way to do that is to edit the `theme` that is attached to the `Balloon` panel in your new copy of the example balloon.

## My balloon

An example of what's possible in a more complicated balloon is what I have in my own game:

![My own balloon](real-example.jpg)  
_With a bit of fiddling, balloons can follow characters._

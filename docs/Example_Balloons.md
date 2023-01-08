# Example Balloons

It's up to you to implement the actual dialogue rendering and input control but there are a few example balloons included to get you started.

You can find them in the [/examples](../examples) directory.

_**NOTE**: The first time you open this project in Godot 4 you'll need to save and then restart Godot (possibly twice) in order to try out the examples. There appears to be an issue with Godot when it initially creates the `.godot` cache folder._

Example scenes include:

- A portrait balloon showing character potraits and typing noises. This also shows using a low res balloon if the viewport is set to lower than 400px.
- Using a mutation to ask the player for their name.
- A Point n Click Adventure style interaction that includes voice acting in multiple languages.

To see an example in action, open the scenes in [/examples/test_scenes](../examples/test_scenes/) and run them.

If you want to run the Point n Click example in German then you will need to open Project Settings and change _Internationalization/Locale/Test_ to be `"de"` (you might need to enable Advanced Settings to see this).

## Copying the example balloon

There is a "Create copy of example dialogue balloon..." item in the _Project > Tools_ menu. When you click it you will be prompted to choose a directory to save the copied files into. From there, you can edit the new balloon to make it your own.

## My balloon

An example of what's possible in a more complicated balloon is what I have in my own game:

![My own balloon](real-example.jpg)  
_With a bit of fiddling, balloons can follow characters._

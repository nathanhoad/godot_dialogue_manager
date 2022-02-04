# Settings

## Editor
- `Check for errors as you type` will do a syntax check after 1 second of inactivity
- `Treat missing translations as errors` can be enabled if you are using static translation keys and are adding them manually (there is an automatic static key button but you might be writing specific keys)

## Runtime

The dialogue runtime itself is stateless, meaning it looks to your game to provide values for variables and for methods to run. At run time, the dialogue manager will check the current scene first and then check any global states provided here.

For example, I have a persistent `GameState` and an ephemeral `SessionState` that my dialogue uses.

![GameState and SessionState are used by dialogue](states.jpg)
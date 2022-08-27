# Settings

## Editor

- `Treat missing translations as errors` can be enabled if you are using static translation keys and are adding them manually (there is an automatic static key button but you might be writing specific keys).
- `Wrap long lines` turns on word wrapping.

## Runtime

- `Include responses with failed conditions` will include responses that failed their condition check in the list of responses attached to a given line.

### Globals shortcuts

The dialogue runtime itself is stateless, meaning it looks to your game to provide values for variables and for methods to run. At run time, the dialogue manager will check the current scene first and then check any globals.

If you don't want to type out a globals' name all of the time you can add it to the globals shortcut list.

For example, instead of having to type out `GameState.some_variable`, you could enable `GameState` and then you would just need to type out `some_variable`.

![GameState and SessionState are used by dialogue](states.jpg)
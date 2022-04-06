# Settings

## Editor

**Compiler**

- `Check for errors as you type` will do a syntax check after 1 second of inactivity.
- `Store compile results in resource` will allow you to turn off pre-baking compile results. When this is off, dialogue resources will be parsed at run time instead.
- `Treat missing translations as errors` can be enabled if you are using static translation keys and are adding them manually (there is an automatic static key button but you might be writing specific keys).

**Editor**

- `Wrap long lines` turns on word wrapping.

## Runtime

**Responses**

- `Include responses with failed conditions` will include responses that failed their condition check in the list of responses attached to a given line.

**Game States**

The dialogue runtime itself is stateless, meaning it looks to your game to provide values for variables and for methods to run. At run time, the dialogue manager will check the current scene first and then check any global states provided here.

For example, I have a persistent `GameState` and an ephemeral `SessionState` that my dialogue uses.

![GameState and SessionState are used by dialogue](states.jpg)
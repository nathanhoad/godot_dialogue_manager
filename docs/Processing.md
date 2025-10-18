# Processing

It is possible to hook into the compilation process in order to modify raw line strings before they are compiled and then also modify compiled lines after they are compiled.

To do so, create a script in your project that extends `DMDialogueProcessor` and then, in **Project Settings > Dialogue Manager > Editor**, point "dialogue processor path" at your script file (make sure Advanced is enabled in order to see the setting).

```gdscript
extends DMDialogueProcessor

func _preprocess_line(raw_string: String) -> String:
  # Replace all apples with oranges.
  return raw_string.replace("apples", "oranges")


func _process_line(line: DMCompiledLine) -> void:
  # Make all dialogue to be spoken by Coco.
  line.character = "Coco"
```

The `_preprocess_line` hook is given each raw line string (as a `String`) before any compilation has happened and expects the modified string to be returned.

The `_process_line` hook is given each compiled line (as a `DMCompiledLine`) after it has been compiled.
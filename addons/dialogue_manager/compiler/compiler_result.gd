## The result of using the [DMCompiler] to compile some dialogue.
class_name DMCompilerResult extends RefCounted


## Any paths that were imported into the compiled dialogue file.
var imported_paths: PackedStringArray = []

## Any "using" directives.
var using_states: PackedStringArray = []

## All cues in the file and the line they point to.
var cues: Dictionary = {}

## The first cue in the file.
var first_cue: String = ""

## All character names.
var character_names: PackedStringArray = []

## Any compilation errors.
var errors: Array[DMError] = []

## A map of all compiled lines.
var lines: Dictionary = {}

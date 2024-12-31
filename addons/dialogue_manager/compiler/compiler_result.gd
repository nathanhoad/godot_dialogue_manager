## The result of using the [DMCompiler] to compile some dialogue.
class_name DMCompilerResult extends RefCounted


## Any paths that were imported into the compiled dialogue file.
var imported_paths: PackedStringArray = []

## Any "using" directives.
var using_states: PackedStringArray = []

## All titles in the file and the line they point to.
var titles: Dictionary = {}

## The first title in the file.
var first_title: String = ""

## All character names.
var character_names: PackedStringArray = []

## Any compilation errors.
var errors: Array[Dictionary] = []

## A map of all compiled lines.
var lines: Dictionary = {}

## The raw dialogue text.
var raw_text: String = ""

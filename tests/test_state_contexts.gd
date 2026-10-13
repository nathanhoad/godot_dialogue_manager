extends AbstractTest


# A stand in for a scene that exposes itself to dialogue with a context node.
class ContextTarget extends Node:
	var was_mutated: bool = false

	func mutate() -> void:
		was_mutated = true


var scene: ContextTarget


func _after_each() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		scene = null


func test_can_mutate_a_context_as_soon_as_it_enters_the_tree() -> void:
	var resource: DialogueResource = create_resource("
~ start
$> thing.mutate()
Nathan: Hello.
=> END")

	# Build a scene that has a context node in it, like one instantiated from the editor.
	scene = ContextTarget.new()
	var context: DialogueStateContext = DialogueStateContext.new()
	context.alias = "thing"
	context.target = scene
	scene.add_child(context)

	# Add the scene to the tree and then start the dialogue without waiting a frame in between, just 
	# like a balloon in that scene with "auto_start" turned on would.
	Engine.get_main_loop().current_scene.add_child(scene)
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource)

	assert(scene.was_mutated, "Should have run the mutation on the context.")
	assert(line.text == "Hello.", "Should have resolved the next line.")

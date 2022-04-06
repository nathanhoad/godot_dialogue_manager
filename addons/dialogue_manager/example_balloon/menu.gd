extends VBoxContainer


signal selection_changed(index, node)
signal actioned(index)


const PRESSED_COUNTER := 90


export var _pointer: NodePath = NodePath()
export var pointer_valign: float = 0.5
export var is_active: bool = true


onready var pointer = get_node_or_null(_pointer)

var index := 0 setget set_index
var up_counter := 0
var page_up_counter := 0
var down_counter := 0
var page_down_counter := 0


func _ready() -> void:
	yield(get_tree(), "idle_frame")
	self.index = index


func _physics_process(_delta: float) -> void:
	if not is_active: return
	
	# Holding down the up or down buttons will skip ahead quickly
	if Input.is_action_pressed("ui_down"):
		down_counter += 1
	else:
		down_counter = 0
	if Input.is_action_pressed("ui_up"):
		up_counter += 1
	else:
		up_counter = 0
	if Input.is_action_pressed("ui_right"):
		page_down_counter += 1
	else:
		page_down_counter = 0
	if Input.is_action_pressed("ui_left"):
		page_up_counter += 1
	else:
		page_up_counter = 0

	if Input.is_action_just_pressed("ui_up") or up_counter >= PRESSED_COUNTER:
		up_counter = clamp(up_counter - 15, 0, PRESSED_COUNTER)
		self.index -= 1
	elif Input.is_action_just_pressed("ui_down") or down_counter >= PRESSED_COUNTER:
		down_counter = clamp(down_counter - 15, 0, PRESSED_COUNTER)
		self.index += 1
	
	elif Input.is_action_just_pressed("ui_right") or page_down_counter >= PRESSED_COUNTER:
		page_down_counter = clamp(page_down_counter - 15, 0, PRESSED_COUNTER)
		self.index += 5
	elif Input.is_action_just_pressed("ui_left") or page_up_counter >= PRESSED_COUNTER:
		page_up_counter = clamp(page_up_counter - 15, 0, PRESSED_COUNTER)
		self.index -= 5
		
	elif Input.is_action_just_pressed("ui_accept"):
		action_item(index)


func set_index(next_index: int) -> void:
	next_index = clamp(next_index, 0, get_child_count() - 1)
	
	if next_index != index:
		index = next_index
		emit_signal("selection_changed", index)
	
	if is_instance_valid(pointer) and index > -1:
		var selected = get_child(index)
		if is_instance_valid(selected):
			pointer.global_position.x = rect_global_position.x - 10
			pointer.global_position.y = selected.rect_global_position.y + selected.rect_size.y * pointer_valign


func action_item(item_index: int) -> void:
	var actioned_node = get_child(item_index)
	
	if actioned_node and not actioned_node.is_allowed: return
	
	is_active = false
	emit_signal("actioned", item_index, actioned_node)


### SIGNAL


func _on_Menu_visibility_changed():
	if pointer != null:
		pointer.visible = visible

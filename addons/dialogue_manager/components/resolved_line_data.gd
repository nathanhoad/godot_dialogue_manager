class_name ResolvedLineData extends RefCounted

var text: String = ""
var pauses: Dictionary = {}
var speeds: Dictionary = {}
var mutations: Array[Array] = []
var conditions: Dictionary = {}
var time = null


func _init(data: Dictionary) -> void:
	text = data.text
	pauses = data.pauses
	speeds = data.speeds
	mutations = data.mutations
	conditions = data.conditions
	time = data.time

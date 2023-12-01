extends RefCounted

var text: String = ""
var pauses: Dictionary = {}
var speeds: Dictionary = {}
var mutations: Array[Array] = []
var time: String = ""


func _init(data: Dictionary) -> void:
	text = data.text
	pauses = data.pauses
	speeds = data.speeds
	mutations = data.mutations
	time = data.time

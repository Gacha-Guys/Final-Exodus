class_name Unit
extends RefCounted

var id: int
var name: String
var index: int
var health: float
var attack: int
var defense: float
var speed: float
var level: int
var multiplier: float
var move_type: int
var target: int
var dealt: int

func _init(data: Dictionary):
	id = int(data["id"])
	name = data["name"]
	index = int(data["index"])
	health = data["health"]
	attack = data["attack"]
	defense = data["defense"]
	speed = data["speed"]
	level = int(data["level"])
	multiplier = data["multiplier"]
	move_type = int(data["move_type"])
	target = int(data["target"])
	dealt = int(data["dealt"])
	
func toDict():
	return {
		"id": id,
		"name": name,
		"index": index,
		"health": health,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"level": level,
		"multiplier": multiplier,
		"move_type": move_type,
		"target": target,
		"dealt": dealt
	}

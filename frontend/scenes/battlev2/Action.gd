class_name Action
extends RefCounted

var move_type: int
var targetIndex: int
var damage: int
var dealt: int

func _init(m: int, t: int, d: int, dt: int):
	move_type = m
	targetIndex = t
	damage = d
	dealt = dt

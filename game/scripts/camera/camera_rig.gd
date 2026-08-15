class_name CameraRig
extends Node2D

@export var look_ahead: float = 180.0
@export var look_ahead_speed: float = 700.0
@export var follow_speed: float = 850.0
@export var fixed_y: float = 360.0
@export var minimum_x: float = 640.0
@export var maximum_x: float = 2560.0

var target: GiantRobotController
var _current_look_ahead: float = 0.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired_look_ahead: float = look_ahead * float(target.facing)
	_current_look_ahead = move_toward(
		_current_look_ahead,
		desired_look_ahead,
		look_ahead_speed * delta
	)
	var desired_x: float = clampf(
		target.global_position.x + _current_look_ahead,
		minimum_x,
		maximum_x
	)
	global_position.x = move_toward(global_position.x, desired_x, follow_speed * delta)
	global_position.y = fixed_y

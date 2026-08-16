class_name HelicopterEnemy
extends EnemyActor2D

enum State {
	APPROACH,
	STRAFE,
	BREAK,
}

@export var maximum_speed: float = 180.0
@export var acceleration: float = 320.0
@export var standoff_x: float = 520.0
@export var lane_y: float = 180.0
@export var fire_interval: float = 2.1
@export var rocket_speed: float = 440.0
@export var rocket_damage: float = 14.0

var state: State = State.APPROACH
var _cooldown: float = 1.0
var _state_time: float = 0.0
var _attack_side: int = 1


func _ready() -> void:
	max_health = 95.0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(AerialDebrisLauncher.AIRBORNE_GROUP)
	super._ready()


func _physics_process(delta: float) -> void:
	if dead or target == null:
		return
	_update_facing()
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var desired_point: Vector2 = Vector2(
		target.global_position.x + float(_attack_side) * standoff_x,
		lane_y
	)
	if state == State.APPROACH and global_position.distance_to(desired_point) < 70.0:
		state = State.STRAFE
		_state_time = 0.0
	elif state == State.STRAFE and _state_time > 4.0:
		state = State.BREAK
		_state_time = 0.0
	elif state == State.BREAK and _state_time > 1.4:
		_attack_side *= -1
		state = State.APPROACH
		_state_time = 0.0
	var desired_velocity: Vector2
	if state == State.BREAK:
		desired_velocity = Vector2(float(_attack_side) * maximum_speed, -35.0)
	else:
		desired_velocity = global_position.direction_to(desired_point) * maximum_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	if state == State.STRAFE and _cooldown <= 0.0:
		_fire_rocket()
		_cooldown = fire_interval
	move_and_slide()


func _fire_rocket() -> void:
	var origin: Vector2 = global_position + Vector2(float(facing) * 62.0, 18.0)
	var direction: Vector2 = origin.direction_to(target.global_position)
	request_projectile(origin, direction, rocket_speed, rocket_damage, &"rocket")

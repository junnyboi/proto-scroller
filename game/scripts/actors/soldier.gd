class_name SoldierEnemy
extends EnemyActor2D

enum State {
	APPROACH,
	AIM,
	ANTICIPATE,
	RETREAT,
}

@export var move_speed: float = 92.0
@export var acceleration: float = 520.0
@export var preferred_range: float = 430.0
@export var minimum_range: float = 250.0
@export var fire_interval: float = 1.15
@export var projectile_speed: float = 720.0
@export var projectile_damage: float = 7.0
@export var anticipation_duration: float = 0.35
@export var gravity: float = 1400.0

var state: State = State.APPROACH
var _cooldown: float = 0.35


func _physics_process(delta: float) -> void:
	if dead or not active:
		return
	if state == State.ANTICIPATE:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		if advance_telegraph(delta):
			_fire_snapshot()
			state = State.AIM
			_cooldown = fire_interval
		move_and_slide()
		update_movement_bounce(delta)
		return
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		move_and_slide()
		update_movement_bounce(delta)
		return
	_update_facing()
	var distance_x: float = absf(target.global_position.x - global_position.x)
	if distance_x > preferred_range + 45.0:
		state = State.APPROACH
	elif distance_x < minimum_range:
		state = State.RETREAT
	else:
		state = State.AIM
	var desired_speed: float = 0.0
	if state == State.APPROACH:
		desired_speed = float(facing) * move_speed
	elif state == State.RETREAT:
		desired_speed = -float(facing) * move_speed
	velocity.x = move_toward(velocity.x, desired_speed, acceleration * delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	if state == State.AIM and _cooldown <= 0.0:
		_begin_fire()
	move_and_slide()
	update_movement_bounce(delta)


func _begin_fire() -> void:
	var muzzle_y: float = visual.position.y - 18.0 if visual != null else -28.0
	var origin: Vector2 = global_position + Vector2(float(facing) * 34.0, muzzle_y)
	var target_point: Vector2 = target.global_position + Vector2(0.0, 45.0)
	if begin_telegraph(&"bullet", anticipation_duration, origin, target_point):
		state = State.ANTICIPATE
	else:
		_cooldown = 0.15


func _fire_snapshot() -> void:
	request_projectile(
		telegraph_origin(),
		telegraph_direction(),
		projectile_speed,
		projectile_damage,
		&"bullet"
	)
	finish_telegraph()


func _reset_archetype_state() -> void:
	state = State.APPROACH
	_cooldown = 0.35

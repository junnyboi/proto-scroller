class_name GiantRobotController
extends CharacterBody2D

signal facing_changed(facing: int)
signal locomotion_changed(state: int)
signal footstep_impact(world_position: Vector2, strength: float)
signal health_changed(current_health: float, maximum_health: float)
signal defeated
signal structure_impact_requested(
	target: Node,
	hit_position: Vector2,
	direction: Vector2,
	impact_speed: float,
	impact_mass: float,
	attack_id: int
)
signal heavy_impact_requested(
	origin: Vector2,
	radius: float,
	damage: float,
	impulse_per_mass: float,
	attack_id: int
)

enum LocomotionState {
	IDLE,
	WALK,
	TURN,
	ATTACK_LOCKED,
	DISABLED,
}

@export_group("Movement")
@export var max_speed: float = 260.0
@export var ground_acceleration: float = 1800.0
@export var ground_deceleration: float = 2200.0
@export var air_acceleration: float = 900.0
@export var gravity: float = 1400.0
@export var max_fall_speed: float = 1000.0
@export_range(0.04, 0.25, 0.01) var turn_duration: float = 0.10

@export_group("Impact")
@export var stomp_radius: float = 96.0
@export var stomp_damage: float = 100.0
@export var stomp_impulse_per_mass: float = 1020.0
@export var landing_speed_for_impact: float = 520.0
@export var structural_impact_mass: float = 48.0
@export var minimum_structural_impact_speed: float = 65.0
@export_range(0.0, 1.0, 0.05) var structural_momentum_retention: float = 0.72

@export_group("Durability")
@export var max_health: float = 120.0

@export_group("References")
@export var visual_root_path: NodePath = ^"VisualRoot"
@export var ground_impact_origin_path: NodePath = ^"GroundImpactOrigin"

var facing: int = 1
var locomotion_state: LocomotionState = LocomotionState.IDLE
var current_health: float
var virtual_move_axis: float = 0.0
var _turn_elapsed: float = 0.0
var _pending_facing: int = 1
var _attack_id: int = 0
var _was_on_floor: bool = false
var _pre_move_vertical_speed: float = 0.0
var _control_enabled: bool = true
var _seen_attacks: Dictionary[int, bool] = {}

@onready var _visual_root: Node2D = get_node_or_null(visual_root_path) as Node2D
@onready var _ground_impact_origin: Node2D = (
	get_node_or_null(ground_impact_origin_path) as Node2D
)


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_stop_on_slope = true
	floor_snap_length = 6.0
	_pending_facing = facing
	current_health = max_health
	_apply_visual_facing()


func _physics_process(delta: float) -> void:
	if _control_enabled and Input.is_action_just_pressed(&"stomp"):
		request_stomp()
	var input_axis: float = Input.get_axis(&"move_left", &"move_right")
	if absf(virtual_move_axis) > absf(input_axis):
		input_axis = virtual_move_axis
	physics_step(input_axis, delta)


func receive_damage(event: DamageEvent) -> bool:
	if event == null or event.amount <= 0.0 or locomotion_state == LocomotionState.DISABLED:
		return false
	if _is_friendly_damage(event):
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	current_health = maxf(current_health - event.amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		set_disabled(true)
		defeated.emit()
	return true


func _is_friendly_damage(event: DamageEvent) -> bool:
	if event.source == null:
		return false
	if event.source == self or is_ancestor_of(event.source):
		return true
	return event.source.get_meta(&"combat_team", &"") == &"player"


func physics_step(input_axis: float, delta: float) -> void:
	if locomotion_state == LocomotionState.DISABLED:
		_apply_gravity(delta)
		move_and_slide()
		return
	_was_on_floor = is_on_floor()
	_pre_move_vertical_speed = velocity.y
	_apply_gravity(delta)
	if _control_enabled and locomotion_state != LocomotionState.ATTACK_LOCKED:
		_update_locomotion(clampf(input_axis, -1.0, 1.0), delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	var requested_velocity: Vector2 = velocity
	move_and_slide()
	_resolve_structure_impacts(requested_velocity)
	_resolve_landing_impact()


func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		virtual_move_axis = 0.0
	if not enabled and locomotion_state != LocomotionState.DISABLED:
		_set_locomotion_state(LocomotionState.ATTACK_LOCKED)
	elif enabled and locomotion_state == LocomotionState.ATTACK_LOCKED:
		_set_locomotion_state(LocomotionState.IDLE)


func set_virtual_move_axis(axis: float) -> void:
	virtual_move_axis = clampf(axis, -1.0, 1.0) if _control_enabled else 0.0


func set_disabled(disabled: bool) -> void:
	_control_enabled = not disabled
	_set_locomotion_state(
		LocomotionState.DISABLED if disabled else LocomotionState.IDLE
	)


func request_stomp() -> int:
	_attack_id += 1
	var origin: Vector2 = (
		_ground_impact_origin.global_position
		if _ground_impact_origin != null
		else global_position
	)
	heavy_impact_requested.emit(
		origin,
		stomp_radius,
		stomp_damage,
		stomp_impulse_per_mass,
		_attack_id
	)
	return _attack_id


func request_structure_impact(
	target: Node,
	hit_position: Vector2,
	direction: Vector2,
	impact_speed: float
) -> int:
	if target == null or impact_speed < minimum_structural_impact_speed:
		return 0
	_attack_id += 1
	var impact_direction: Vector2 = direction.normalized()
	if impact_direction.is_zero_approx():
		impact_direction = Vector2(float(facing), 0.0)
	structure_impact_requested.emit(
		target,
		hit_position,
		impact_direction,
		impact_speed,
		structural_impact_mass,
		_attack_id
	)
	return _attack_id


func notify_footstep(strength: float = 1.0) -> void:
	var origin: Vector2 = (
		_ground_impact_origin.global_position
		if _ground_impact_origin != null
		else global_position
	)
	footstep_impact.emit(origin, clampf(strength, 0.0, 2.0))


func _update_locomotion(input_axis: float, delta: float) -> void:
	var desired_facing: int = _sign_to_facing(input_axis)
	if locomotion_state != LocomotionState.TURN:
		if desired_facing != 0 and desired_facing != facing:
			_begin_turn(desired_facing)
		else:
			_apply_horizontal_motion(input_axis, delta)
		return
	_turn_elapsed += delta
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	if _turn_elapsed >= turn_duration * 0.5 and facing != _pending_facing:
		facing = _pending_facing
		_apply_visual_facing()
		facing_changed.emit(facing)
	if _turn_elapsed >= turn_duration:
		_set_locomotion_state(LocomotionState.IDLE)
		_apply_horizontal_motion(input_axis, delta)


func _apply_horizontal_motion(input_axis: float, delta: float) -> void:
	var target_speed: float = input_axis * max_speed
	var acceleration: float
	if not is_on_floor():
		acceleration = air_acceleration
	elif not is_zero_approx(input_axis):
		acceleration = ground_acceleration
	else:
		acceleration = ground_deceleration
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	_set_locomotion_state(
		LocomotionState.WALK
		if absf(velocity.x) > 1.0
		else LocomotionState.IDLE
	)


func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _resolve_landing_impact() -> void:
	if _was_on_floor or not is_on_floor():
		return
	if _pre_move_vertical_speed < landing_speed_for_impact:
		return
	var strength: float = clampf(
		_pre_move_vertical_speed / maxf(landing_speed_for_impact, 1.0),
		1.0,
		2.0
	)
	notify_footstep(strength)


func _resolve_structure_impacts(requested_velocity: Vector2) -> void:
	if requested_velocity.is_zero_approx():
		return
	var seen: Dictionary[int, bool] = {}
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		var collider: Node = collision.get_collider() as Node
		var target: Node = _find_damage_receiver(collider)
		if target == null or seen.has(target.get_instance_id()):
			continue
		var approach_speed: float = maxf(
			-requested_velocity.dot(collision.get_normal()),
			0.0
		)
		if approach_speed < minimum_structural_impact_speed:
			continue
		seen[target.get_instance_id()] = true
		request_structure_impact(
			target,
			collision.get_position(),
			requested_velocity,
			approach_speed
		)
		velocity.x = requested_velocity.x * structural_momentum_retention
func _find_damage_receiver(start_node: Node) -> Node:
	var receiver: Node = start_node
	while receiver != null:
		if receiver.has_method("receive_damage"):
			return receiver
		receiver = receiver.get_parent()
	return null


func _begin_turn(new_facing: int) -> void:
	_pending_facing = new_facing
	_turn_elapsed = 0.0
	_set_locomotion_state(LocomotionState.TURN)


func _sign_to_facing(value: float) -> int:
	if value > 0.01:
		return 1
	if value < -0.01:
		return -1
	return 0


func _apply_visual_facing() -> void:
	if _visual_root != null:
		_visual_root.scale.x = absf(_visual_root.scale.x) * float(facing)


func _set_locomotion_state(next_state: LocomotionState) -> void:
	if locomotion_state == next_state:
		return
	locomotion_state = next_state
	locomotion_changed.emit(locomotion_state)

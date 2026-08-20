class_name GiantRobotController
extends CharacterBody2D

signal facing_changed(facing: int)
signal locomotion_changed(state: int)
signal footstep_impact(world_position: Vector2, strength: float)
signal health_changed(current_health: float, maximum_health: float)
signal damage_received(event: DamageEvent, accepted_damage: float)
signal defeated
signal attack_mode_selected(mode: int, attack_id: int)
signal attack_committed(mode: int, attack_id: int)
signal dodge_started(facing: int, duration: float)
signal dodge_finished
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
	DODGE,
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

@export_group("Dodge")
@export var dodge_speed: float = 520.0
@export var dodge_duration: float = 0.18
@export var dodge_invulnerability_seconds: float = 0.30
@export var dodge_recovery_seconds: float = 0.12
@export var dodge_cooldown_seconds: float = 1.20
@export_range(0.15, 0.45, 0.01) var dodge_double_tap_window: float = 0.28

@export_group("Impact")
@export var stomp_radius: float = 96.0
@export var stomp_damage: float = 100.0
@export var stomp_impulse_per_mass: float = 1020.0
@export var landing_speed_for_impact: float = 520.0

@export_group("Durability")
@export var max_health: float = 120.0

@export_group("References")
@export var visual_root_path: NodePath = ^"VisualRoot"
@export var ground_impact_origin_path: NodePath = ^"GroundImpactOrigin"

var facing: int = 1
var locomotion_state: LocomotionState = LocomotionState.IDLE
var current_health: float
var virtual_move_axis: float = 0.0
var acceleration_multiplier: float = 1.0
var attack_controller: ContextualAttackController
var base_max_health: float = 0.0
var base_max_speed: float = 0.0
var base_ground_acceleration: float = 0.0
var base_air_acceleration: float = 0.0
var base_ground_deceleration: float = 0.0
var base_dodge_speed: float = 0.0
var base_dodge_duration: float = 0.0
var dodge_count: int = 0
var invulnerable_rejection_count: int = 0
var dodge_invulnerable: bool:
	get:
		return _invulnerable_remaining > 0.0
var dodge_invulnerability_remaining: float:
	get:
		return _invulnerable_remaining
var dodge_recovery_remaining: float:
	get:
		return _dodge_recovery_remaining
var dodge_cooldown_remaining: float = 0.0
var dodge_cooldown_ratio: float:
	get:
		if dodge_cooldown_seconds <= 0.0:
			return 0.0
		return clampf(dodge_cooldown_remaining / dodge_cooldown_seconds, 0.0, 1.0)
var dodge_ready: bool:
	get:
		return is_zero_approx(dodge_cooldown_remaining)
var _turn_elapsed: float = 0.0
var _pending_facing: int = 1
var _attack_id: int = 0
var _was_on_floor: bool = false
var _pre_move_vertical_speed: float = 0.0
var _control_enabled: bool = true
var _attack_locked: bool = false
var _dodge_remaining: float = 0.0
var _invulnerable_remaining: float = 0.0
var _dodge_recovery_remaining: float = 0.0
var _tap_window_remaining: float = 0.0
var _last_tap_direction: int = 0
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
	base_max_health = max_health
	base_max_speed = max_speed
	base_ground_acceleration = ground_acceleration
	base_air_acceleration = air_acceleration
	base_ground_deceleration = ground_deceleration
	base_dodge_speed = dodge_speed
	base_dodge_duration = dodge_duration
	current_health = max_health
	_apply_visual_facing()


func _physics_process(delta: float) -> void:
	if _control_enabled and Input.is_action_just_pressed(&"stomp"):
		request_attack()
	if _control_enabled and Input.is_action_just_pressed(&"move_left"):
		_register_move_tap(-1)
	elif _control_enabled and Input.is_action_just_pressed(&"move_right"):
		_register_move_tap(1)
	var input_axis: float = Input.get_axis(&"move_left", &"move_right")
	if absf(virtual_move_axis) > absf(input_axis):
		input_axis = virtual_move_axis
	physics_step(input_axis, delta)


func receive_damage(event: DamageEvent) -> bool:
	if event == null or event.amount <= 0.0 or locomotion_state == LocomotionState.DISABLED:
		return false
	if _invulnerable_remaining > 0.0:
		invulnerable_rejection_count += 1
		return false
	if _is_friendly_damage(event):
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	var previous_health: float = current_health
	current_health = maxf(current_health - event.amount, 0.0)
	damage_received.emit(event, previous_health - current_health)
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
	_invulnerable_remaining = maxf(_invulnerable_remaining - delta, 0.0)
	dodge_cooldown_remaining = maxf(dodge_cooldown_remaining - delta, 0.0)
	_tap_window_remaining = maxf(_tap_window_remaining - delta, 0.0)
	if is_zero_approx(_tap_window_remaining):
		_last_tap_direction = 0
	if locomotion_state == LocomotionState.DISABLED:
		_apply_gravity(delta)
		move_and_slide()
		return
	_was_on_floor = is_on_floor()
	_pre_move_vertical_speed = velocity.y
	_apply_gravity(delta)
	if locomotion_state == LocomotionState.DODGE:
		velocity.x = float(facing) * dodge_speed
		move_and_slide()
		_dodge_remaining = maxf(_dodge_remaining - delta, 0.0)
		if is_zero_approx(_dodge_remaining):
			velocity.x = 0.0
			_dodge_recovery_remaining = dodge_recovery_seconds
			_set_locomotion_state(LocomotionState.IDLE)
			dodge_finished.emit()
		_resolve_landing_impact()
		return
	if _dodge_recovery_remaining > 0.0:
		_dodge_recovery_remaining = maxf(_dodge_recovery_remaining - delta, 0.0)
		velocity.x = 0.0
		move_and_slide()
		_resolve_landing_impact()
		return
	if _control_enabled and locomotion_state != LocomotionState.ATTACK_LOCKED:
		_update_locomotion(clampf(input_axis, -1.0, 1.0), delta)
	else:
		velocity.x = 0.0
	move_and_slide()
	_resolve_landing_impact()


func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		virtual_move_axis = 0.0
		_clear_move_tap()
	if not enabled and locomotion_state != LocomotionState.DISABLED:
		_set_locomotion_state(LocomotionState.ATTACK_LOCKED)
	elif enabled and locomotion_state == LocomotionState.ATTACK_LOCKED and not _attack_locked:
		_set_locomotion_state(LocomotionState.IDLE)


func set_virtual_move_axis(axis: float) -> void:
	virtual_move_axis = clampf(axis, -1.0, 1.0) if _control_enabled else 0.0


func set_acceleration_multiplier(multiplier: float) -> void:
	acceleration_multiplier = clampf(multiplier, 1.0, 1.5)


func set_durability_bonus(total_bonus: float) -> bool:
	var next_maximum: float = base_max_health + maxf(total_bonus, 0.0)
	if is_equal_approx(next_maximum, max_health):
		return false
	var missing_health: float = maxf(max_health - current_health, 0.0)
	var was_defeated: bool = current_health <= 0.0
	max_health = next_maximum
	current_health = 0.0 if was_defeated else maxf(max_health - missing_health, 0.0)
	current_health = minf(current_health, max_health)
	health_changed.emit(current_health, max_health)
	return true


func set_engine_multipliers(
	speed_multiplier: float,
	acceleration_scale: float,
	deceleration_scale: float
) -> bool:
	var next_speed: float = base_max_speed * maxf(speed_multiplier, 1.0)
	var next_ground_accel: float = base_ground_acceleration * maxf(acceleration_scale, 1.0)
	var next_air_accel: float = base_air_acceleration * maxf(acceleration_scale, 1.0)
	var next_deceleration: float = (
		base_ground_deceleration * maxf(deceleration_scale, 1.0)
	)
	if (
		is_equal_approx(max_speed, next_speed)
		and is_equal_approx(ground_acceleration, next_ground_accel)
		and is_equal_approx(air_acceleration, next_air_accel)
		and is_equal_approx(ground_deceleration, next_deceleration)
	):
		return false
	var previous_speed: float = maxf(max_speed, 1.0)
	var preserve_overspeed: bool = absf(velocity.x) > previous_speed
	var signed_ratio: float = velocity.x / previous_speed
	max_speed = next_speed
	ground_acceleration = next_ground_accel
	air_acceleration = next_air_accel
	ground_deceleration = next_deceleration
	if not preserve_overspeed:
		velocity.x = signed_ratio * max_speed
	return true


func _set_dodge_multipliers(speed_multiplier: float, duration_multiplier: float) -> bool:
	var next_speed: float = base_dodge_speed * maxf(speed_multiplier, 1.0)
	var next_duration: float = base_dodge_duration * maxf(duration_multiplier, 1.0)
	if is_equal_approx(dodge_speed, next_speed) and is_equal_approx(
		dodge_duration,
		next_duration
	):
		return false
	dodge_speed = next_speed
	dodge_duration = next_duration
	return true


func set_attack_controller(controller: ContextualAttackController) -> void:
	attack_controller = controller


func _set_attack_locked(locked: bool) -> void:
	_attack_locked = locked
	if locomotion_state == LocomotionState.DISABLED or locomotion_state == LocomotionState.DODGE:
		return
	if locked:
		velocity.x = 0.0
	_set_locomotion_state(
		LocomotionState.ATTACK_LOCKED
		if locked
		else LocomotionState.IDLE
	)


func _register_move_tap(direction: int) -> bool:
	var normalized_direction: int = clampi(direction, -1, 1)
	if normalized_direction == 0 or not _control_enabled:
		return false
	var is_double_tap: bool = (
		normalized_direction == _last_tap_direction
		and _tap_window_remaining > 0.0
	)
	_last_tap_direction = normalized_direction
	_tap_window_remaining = dodge_double_tap_window
	if not is_double_tap:
		return false
	_clear_move_tap()
	if attack_controller != null:
		return attack_controller.request_dodge(normalized_direction)
	return _start_dodge(normalized_direction)


func _clear_move_tap() -> void:
	_last_tap_direction = 0
	_tap_window_remaining = 0.0


func _start_dodge(direction: int = 0) -> bool:
	if (
		not _control_enabled
		or locomotion_state == LocomotionState.DISABLED
		or _attack_locked
		or _dodge_recovery_remaining > 0.0
		or not dodge_ready
	):
		return false
	var dodge_direction: int = clampi(direction, -1, 1)
	if dodge_direction == 0:
		dodge_direction = facing
	if facing != dodge_direction:
		facing = dodge_direction
		_pending_facing = facing
		_apply_visual_facing()
		facing_changed.emit(facing)
	_dodge_remaining = dodge_duration
	_invulnerable_remaining = dodge_invulnerability_seconds
	dodge_cooldown_remaining = dodge_cooldown_seconds
	velocity.x = float(facing) * dodge_speed
	_set_locomotion_state(LocomotionState.DODGE)
	dodge_count += 1
	dodge_started.emit(facing, dodge_duration)
	return true


func set_disabled(disabled: bool) -> void:
	_control_enabled = not disabled
	if disabled:
		_clear_move_tap()
	_set_locomotion_state(
		LocomotionState.DISABLED
		if disabled
		else (
			LocomotionState.ATTACK_LOCKED
			if _attack_locked
			else LocomotionState.IDLE
		)
	)


func request_stomp() -> int:
	var attack_id: int = reserve_attack_id()
	execute_ground_smash(attack_id)
	return attack_id


func request_attack() -> int:
	if attack_controller != null:
		return attack_controller.request_attack()
	return request_stomp()


func reserve_attack_id() -> int:
	_attack_id += 1
	return _attack_id


func can_request_attack() -> bool:
	return (
		_control_enabled
		and locomotion_state != LocomotionState.DISABLED
		and locomotion_state != LocomotionState.DODGE
		and _dodge_recovery_remaining <= 0.0
	)


func execute_ground_smash(attack_id: int) -> void:
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
		attack_id
	)


func notify_attack_selected(mode: int, attack_id: int) -> void:
	attack_mode_selected.emit(mode, attack_id)


func notify_attack_committed(mode: int, attack_id: int) -> void:
	attack_committed.emit(mode, attack_id)


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
		acceleration = ground_acceleration * acceleration_multiplier
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
		var baked_facing: bool = bool(_visual_root.get_meta(&"baked_directional_art", false))
		_visual_root.scale.x = (
			absf(_visual_root.scale.x) * (1.0 if baked_facing else float(facing))
		)


func _set_locomotion_state(next_state: LocomotionState) -> void:
	if locomotion_state == next_state:
		return
	locomotion_state = next_state
	locomotion_changed.emit(locomotion_state)

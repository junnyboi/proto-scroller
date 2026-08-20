class_name ProceduralEnemy
extends EnemyActor2D

enum State {
	APPROACH,
	HOLD,
	ANTICIPATE,
	BREAK,
}

const GRAVITY: float = 1400.0
const MARK_DURATION: float = 3.0
const SUPPORT_RADIUS: float = 520.0

var archetype_id: StringName = &""
var profile: Dictionary = {}
var family: StringName = &""
var airborne: bool = false
var display_name: String = ""
var move_speed: float = 90.0
var acceleration: float = 450.0
var preferred_range: float = 420.0
var minimum_range: float = 240.0
var attack_interval: float = 2.0
var projectile_kind: StringName = &"bullet"
var projectile_speed: float = 700.0
var projectile_damage: float = 8.0
var anticipation_duration: float = 0.6
var behavior: StringName = &"ground_standoff"
var movement_style: StringName = &"heavy_march"
var attack_style: StringName = &"turret_burst"
var xp_value: int = 500
var threat_cost: int = 1
var remains_family: StringName = &"vehicle"
var encounter_runtime: EncounterRuntime

var state: State = State.APPROACH
var _cooldown: float = 0.4
var _state_time: float = 0.0
var _animation_phase: float = 0.0
var _attack_kick: float = 0.0
var _pass_side: int = 1
var _spawned_children: int = 0
var _attack_sequence: int = 0
var _lane_y: float = 190.0
var _extra_projectile_reservations: Array[int] = []


func configure_archetype(p_archetype_id: StringName, p_profile: Dictionary) -> void:
	archetype_id = p_archetype_id
	profile = p_profile.duplicate(true)
	display_name = String(profile.get("display_name", String(archetype_id).to_upper()))
	family = StringName(profile.get("family", &""))
	airborne = bool(profile.get("airborne", false))
	max_health = float(profile.get("health", 60.0))
	_base_max_health = max_health
	move_speed = float(profile.get("speed", 90.0))
	acceleration = float(profile.get("acceleration", 450.0))
	preferred_range = float(profile.get("preferred_range", 420.0))
	minimum_range = float(profile.get("minimum_range", 240.0))
	attack_interval = float(profile.get("attack_interval", 2.0))
	projectile_kind = StringName(profile.get("projectile_kind", &"bullet"))
	projectile_speed = float(profile.get("projectile_speed", 700.0))
	projectile_damage = float(profile.get("damage", 8.0))
	anticipation_duration = float(profile.get("anticipation", 0.6))
	behavior = StringName(profile.get("behavior", &"ground_standoff"))
	movement_style = StringName(profile.get("movement_style", &"heavy_march"))
	attack_style = StringName(profile.get("attack_style", &"turret_burst"))
	xp_value = int(profile.get("xp", 500))
	threat_cost = int(profile.get("threat", 1))
	remains_family = StringName(profile.get("remains", &"vehicle"))
	_lane_y = float(profile.get("spawn_y", 190.0))
	if airborne:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		add_to_group(AerialDebrisLauncher.AIRBORNE_GROUP)


func _ready() -> void:
	super._ready()
	set_meta(&"enemy_archetype", archetype_id)
	set_meta(&"enemy_family", family)


func _physics_process(delta: float) -> void:
	if dead or not active:
		return
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if state == State.ANTICIPATE:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		if advance_telegraph(delta):
			_complete_attack()
			state = State.HOLD
			_state_time = 0.0
			_cooldown = (
				attack_interval
				* attack_interval_multiplier
				* external_attack_interval_multiplier
				* aura_attack_interval_multiplier
			)
		move_and_slide()
		_animate_visual(delta)
		return
	if target == null:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		if not airborne:
			velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
		move_and_slide()
		_animate_visual(delta)
		return
	_update_facing()
	if airborne:
		_update_air_movement(delta)
	else:
		_update_ground_movement(delta)
	if _cooldown <= 0.0 and _can_attack():
		_begin_attack()
	move_and_slide()
	_animate_visual(delta)


func receive_damage(event: DamageEvent) -> bool:
	if archetype_id == &"bulwark" and event != null and event.damage_type != &"ground_smash":
		var incoming_dot: float = event.direction.normalized().dot(Vector2(float(facing), 0.0))
		if incoming_dot < -0.35:
			return super.receive_damage(event.scaled(0.28))
	return super.receive_damage(event)


func _update_ground_movement(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	var distance_x: float = absf(target.global_position.x - global_position.x)
	var desired_speed: float = 0.0
	if behavior == &"ground_pass":
		if state != State.BREAK and distance_x < minimum_range + 80.0:
			state = State.BREAK
			_state_time = 0.0
			_pass_side = facing
		if state == State.BREAK:
			desired_speed = float(_pass_side) * move_speed * movement_multiplier
			if _state_time > 1.25:
				state = State.APPROACH
			else:
				desired_speed = float(facing) * move_speed * movement_multiplier
	elif behavior == &"ground_close":
		desired_speed = (
			float(facing) * move_speed * movement_multiplier
			if distance_x > minimum_range
			else 0.0
		)
	elif distance_x > preferred_range + 45.0:
		state = State.APPROACH
		desired_speed = float(facing) * move_speed * movement_multiplier
	elif distance_x < minimum_range:
		state = State.BREAK
		desired_speed = -float(facing) * move_speed * movement_multiplier
	else:
		state = State.HOLD
	velocity.x = move_toward(velocity.x, desired_speed, acceleration * delta)


func _update_air_movement(delta: float) -> void:
	var desired_point: Vector2
	if behavior == &"air_pass":
		if state != State.BREAK and absf(target.global_position.x - global_position.x) < 190.0:
			state = State.BREAK
			_state_time = 0.0
			_pass_side = facing
		if state == State.BREAK:
			desired_point = Vector2(
				target.global_position.x + float(_pass_side) * 760.0,
				_lane_y - 35.0
			)
			if _state_time > 1.6:
				state = State.APPROACH
		else:
			desired_point = Vector2(
				target.global_position.x + float(facing) * preferred_range,
				_lane_y
			)
	elif behavior == &"air_close":
		desired_point = target.global_position + Vector2(float(-facing) * minimum_range, -150.0)
	else:
		desired_point = Vector2(
			target.global_position.x - float(facing) * preferred_range,
			_lane_y
		)
	var desired_velocity: Vector2 = (
		global_position.direction_to(desired_point) * move_speed * movement_multiplier
	)
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func _can_attack() -> bool:
	if not attack_gate_enabled or state == State.ANTICIPATE:
		return false
	var distance_x: float = absf(target.global_position.x - global_position.x)
	if behavior in [&"ground_pass", &"air_pass"]:
		return distance_x < preferred_range
	if behavior in [&"ground_close", &"air_close"]:
		return distance_x <= preferred_range + 80.0
	return distance_x <= preferred_range + 110.0


func _begin_attack() -> void:
	var origin: Vector2 = global_position + Vector2(float(facing) * 48.0, -18.0)
	if airborne:
		origin = global_position + Vector2(float(facing) * 52.0, 15.0)
	var target_point: Vector2 = target.global_position + Vector2(0.0, 30.0)
	if attack_style == &"bomb_drop":
		target_point += Vector2(target.velocity.x * 0.35, 55.0)
	var telegraph_kind: StringName = projectile_kind
	if attack_style in [
		&"scan", &"repair", &"jammer_pulse", &"shield_pulse", &"deploy", &"drone_launch",
	]:
		telegraph_kind = &"support"
	if not begin_telegraph(telegraph_kind, anticipation_duration, origin, target_point):
		_cooldown = 0.2
		return
	var extra_shots: int = 0
	if attack_style == &"pod_salvo":
		extra_shots = 2
	elif attack_style == &"fortress_barrage":
		extra_shots = 3
	if extra_shots > 0 and not _reserve_extra_projectiles(extra_shots):
		cancel_telegraph()
		_cooldown = 0.2
		return
	state = State.ANTICIPATE
	_state_time = 0.0
	_attack_kick = 1.0


func _complete_attack() -> void:
	_attack_sequence += 1
	_attack_kick = 1.0
	if attack_style == &"scan":
		if encounter_runtime != null:
			encounter_runtime.apply_target_mark(MARK_DURATION)
		finish_telegraph()
		return
	if attack_style == &"repair":
		_repair_nearest_ally()
		finish_telegraph()
		return
	if attack_style in [&"jammer_pulse", &"shield_pulse"]:
		finish_telegraph()
		return
	if attack_style in [&"deploy", &"drone_launch"]:
		_try_spawn_reinforcement()
		finish_telegraph()
		return
	if (
		attack_style == &"lance_thrust"
		and global_position.distance_to(target.global_position) <= 245.0
	):
		var attack_id: int = activation_generation * 1000 + _attack_sequence
		target.receive_damage(DamageEvent.new(
			attack_id,
			self,
			projectile_damage * projectile_damage_multiplier * aura_damage_multiplier,
			&"lance",
			target.global_position,
			global_position.direction_to(target.global_position),
			520.0
		))
		finish_telegraph()
		return
	var first: Projectile2D = fire_telegraphed_projectile(
		projectile_speed,
		projectile_damage * projectile_damage_multiplier * aura_damage_multiplier
	)
	if first == null:
		return
	if attack_style in [&"pod_salvo", &"fortress_barrage"]:
		_fire_spread_projectiles(2 if attack_style == &"pod_salvo" else 3)


func _fire_spread_projectiles(extra_count: int) -> void:
	if projectile_pool == null or target == null:
		_release_extra_projectile_reservations()
		return
	for shot_index: int in range(extra_count):
		if _extra_projectile_reservations.is_empty():
			return
		var reservation_id: int = _extra_projectile_reservations.pop_front()
		var offset: float = (float(shot_index) - float(extra_count - 1) * 0.5) * 95.0
		var destination: Vector2 = target.global_position + Vector2(offset, 30.0)
		projectile_pool.acquire_reserved(
			reservation_id,
			telegraph_origin(),
			telegraph_origin().direction_to(destination),
			projectile_speed * (0.92 + float(shot_index) * 0.06),
			projectile_damage * 0.72 * projectile_damage_multiplier * aura_damage_multiplier,
			self,
			projectile_target_mask,
			projectile_kind
		)


func cancel_telegraph() -> void:
	_release_extra_projectile_reservations()
	super.cancel_telegraph()


func _reserve_extra_projectiles(count: int) -> bool:
	_release_extra_projectile_reservations()
	for reservation_index: int in range(count):
		var reservation_id: int = projectile_pool.reserve(projectile_kind)
		if reservation_id == 0:
			_release_extra_projectile_reservations()
			return false
		_extra_projectile_reservations.append(reservation_id)
	return true


func _release_extra_projectile_reservations() -> void:
	if projectile_pool != null:
		for reservation_id: int in _extra_projectile_reservations:
			projectile_pool.cancel_reservation(reservation_id)
	_extra_projectile_reservations.clear()


func _try_spawn_reinforcement() -> bool:
	if encounter_runtime == null:
		return false
	var spawn_limit: int = int(profile.get("spawn_limit", 0))
	if _spawned_children >= spawn_limit:
		return false
	var spawn_kind: StringName = StringName(profile.get("spawn_kind", &""))
	if spawn_kind.is_empty():
		return false
	var spawn_position: Vector2 = global_position + Vector2(-float(facing) * 120.0, 0.0)
	var spawned: EnemyActor2D = encounter_runtime.acquire(spawn_kind, spawn_position)
	if spawned == null:
		return false
	_spawned_children += 1
	return true


func _repair_nearest_ally() -> void:
	if encounter_runtime == null:
		return
	var best: EnemyActor2D
	var best_distance: float = SUPPORT_RADIUS
	for actor: EnemyActor2D in encounter_runtime.all_actors():
		if actor == self or not actor.active or actor.dead or actor.current_health >= actor.max_health:
			continue
		var distance: float = global_position.distance_to(actor.global_position)
		if distance < best_distance:
			best = actor
			best_distance = distance
	if best != null:
		best.current_health = minf(best.current_health + 22.0, best.max_health)
		if best.visual != null:
			best.visual.modulate = Color("9bffd1")
			var tween: Tween = best.create_tween()
			tween.tween_property(best.visual, "modulate", Color.WHITE, 0.2)


func _animate_visual(delta: float) -> void:
	if visual == null:
		return
	var speed_ratio: float = clampf(velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0)
	_animation_phase = fmod(_animation_phase + delta * TAU * lerpf(1.3, 4.2, speed_ratio), TAU)
	_attack_kick = maxf(_attack_kick - delta * 2.8, 0.0)
	var attack_envelope: float = sin((1.0 - _attack_kick) * PI) if _attack_kick > 0.0 else 0.0
	var offset: Vector2 = Vector2.ZERO
	var scale_factor: Vector2 = Vector2.ONE
	var rotation_value: float = 0.0
	match movement_style:
		&"drone_hover":
			offset.y = sin(_animation_phase) * 6.0
			rotation_value = sin(_animation_phase * 0.7) * 0.025
		&"shield_march":
			offset.y = -absf(sin(_animation_phase)) * 3.0 * speed_ratio
			rotation_value = -0.035 * float(facing) * speed_ratio
		&"wheel_sprint":
			offset.y = sin(_animation_phase * 2.0) * 2.2 * speed_ratio
			rotation_value = -velocity.x / maxf(move_speed, 1.0) * 0.018
		&"heavy_march", &"utility_march", &"team_shuffle":
			offset.y = -absf(sin(_animation_phase)) * 4.0 * speed_ratio
			rotation_value = sin(_animation_phase) * 0.018 * float(facing)
		&"hunter_lunge":
			offset.y = sin(_animation_phase) * 8.0
			rotation_value = velocity.x / maxf(move_speed, 1.0) * 0.06
		&"apc_roll", &"tracked_heavy", &"capacitor_roll":
			offset.y = sin(_animation_phase * 2.0) * 1.4 * speed_ratio
			rotation_value = sin(_animation_phase) * 0.009 * speed_ratio
		&"antenna_sway", &"dish_pulse":
			offset.y = sin(_animation_phase) * 1.5
			rotation_value = sin(_animation_phase * 0.5) * 0.012
		&"bomber_bank", &"vtol_strafe":
			offset.y = sin(_animation_phase) * 5.0
			rotation_value = clampf(velocity.x / maxf(move_speed, 1.0), -1.0, 1.0) * 0.075
		&"flame_lurch":
			offset.y = -absf(sin(_animation_phase)) * 2.0 * speed_ratio
			rotation_value = -0.022 * float(facing) * speed_ratio
		&"carrier_hover":
			offset.y = sin(_animation_phase * 0.65) * 7.0
			rotation_value = sin(_animation_phase * 0.4) * 0.018
		&"walker_stride":
			offset.y = -absf(sin(_animation_phase)) * 6.0 * speed_ratio
			rotation_value = sin(_animation_phase) * 0.026 * float(facing)
		&"mech_stride":
			offset.y = -absf(sin(_animation_phase)) * 8.0 * speed_ratio
			rotation_value = -0.04 * float(facing) * speed_ratio
		&"landship_rumble":
			offset = Vector2(sin(_animation_phase * 2.0), cos(_animation_phase * 3.0)) * 1.5
	if attack_envelope > 0.0:
		match attack_style:
			&"scan", &"jammer_pulse", &"shield_pulse":
				scale_factor = Vector2.ONE * (1.0 + attack_envelope * 0.055)
			&"lob", &"mortar_recoil", &"missile_launch", &"pod_salvo", \
			&"wing_launch", &"bomb_drop", &"rail_recoil", &"fortress_barrage":
				offset.x -= float(facing) * attack_envelope * 12.0
				rotation_value -= float(facing) * attack_envelope * 0.045
			&"repair", &"deploy", &"drone_launch":
				offset.y += attack_envelope * 5.0
				scale_factor = Vector2(1.0 + attack_envelope * 0.03, 1.0 - attack_envelope * 0.03)
			&"lance_thrust", &"flame_blast", &"autocannon":
				offset.x += float(facing) * attack_envelope * 14.0
				rotation_value += float(facing) * attack_envelope * 0.04
			_:
				offset.x -= float(facing) * attack_envelope * 5.0
	if EnemyArchetypeCatalog.is_human_enemy(archetype_id):
		scale_factor.y = 1.0
	visual.position = _visual_rest_position + offset
	visual.scale = _visual_rest_scale * scale_factor
	visual.rotation = rotation_value


func _reset_archetype_state() -> void:
	state = State.APPROACH
	_cooldown = 0.35
	_state_time = 0.0
	_animation_phase = 0.0
	_attack_kick = 0.0
	_pass_side = facing
	_spawned_children = 0
	_attack_sequence = 0

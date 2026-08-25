extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func after_each() -> void:
	_release_test_actions()


func test_resolver_locks_ground_at_699_and_jab_cross_at_700() -> void:
	var resolver: AttackResolver = AttackResolver.new()
	add_child_autofree(resolver)
	var ground: AttackSpec = resolver.resolve(1, 1, 0.699, 180.0, 1020.0, 320.0)
	var jab_cross: AttackSpec = resolver.resolve(2, -1, 0.700, 180.0, 1020.0, 320.0)
	assert_true(ground.is_ground_smash())
	assert_eq(ground.facing, 1)
	assert_almost_eq(ground.speed_ratio, 0.699, 0.0001)
	assert_true(jab_cross.is_jab_cross())
	assert_eq(jab_cross.facing, -1)
	assert_almost_eq(jab_cross.speed_ratio, 0.700, 0.0001)
	assert_almost_eq(
		jab_cross.anticipation_seconds,
		AttackResolver.FULL_ANTICIPATION_SECONDS,
		0.0001
	)
	assert_almost_eq(jab_cross.active_seconds, AttackResolver.FULL_ACTIVE_SECONDS, 0.0001)
	assert_almost_eq(
		jab_cross.recovery_seconds,
		AttackResolver.FULL_RECOVERY_SECONDS,
		0.0001
	)
	assert_almost_eq(
		ground.anticipation_seconds + ground.active_seconds + ground.recovery_seconds,
		AttackResolver.FULL_ATTACK_SECONDS,
		0.0001
	)
	assert_almost_eq(
		jab_cross.anticipation_seconds
		+ jab_cross.active_seconds
		+ jab_cross.recovery_seconds,
		AttackResolver.FULL_ATTACK_SECONDS,
		0.0001
	)
	assert_almost_eq(jab_cross.actor_damage, 145.0, 0.001)
	assert_almost_eq(jab_cross.structural_damage, 125.0, 0.001)
	assert_almost_eq(jab_cross.impulse_per_mass, 1080.0, 0.001)
	_record_test_execution()


func test_ground_smash_uses_locked_mode_after_velocity_changes() -> void:
	var city: CitySlice = await _city()
	city.car.current_health = 1.0
	city.robot.velocity.x = city.robot.max_speed * 0.699
	var attack_id: int = city.robot.request_attack()
	var spec: AttackSpec = city.contextual_attacks.current_spec
	assert_gt(attack_id, 0)
	assert_true(spec.is_ground_smash())
	city.robot.velocity.x = city.robot.max_speed
	await get_tree().create_timer(spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(city.car.is_broken)
	assert_eq(city.contextual_attacks.jab_cross_impact.last_accepted_targets, 0)
	_record_test_execution()


func test_tap_charge_releases_normal_damage_and_full_charge_caps_at_double_damage() -> void:
	var city: CitySlice = await _city()
	var attacks: ContextualAttackController = city.contextual_attacks
	assert_gt(attacks.begin_charge(), 0)
	assert_true(attacks.is_charging())
	assert_eq(attacks.phase, ContextualAttackController.Phase.CHARGING)
	assert_almost_eq(attacks.charge_duration(), 0.0, 0.0001)
	assert_almost_eq(attacks.charge_damage_multiplier(), 1.0, 0.0001)
	assert_true(attacks.release_charge())
	assert_almost_eq(attacks.current_spec.actor_damage, 180.0, 0.001)
	assert_almost_eq(attacks.current_spec.structural_damage, 180.0, 0.001)
	attacks.cancel_attack()
	assert_gt(attacks.begin_charge(), 0)
	attacks._process(3.5)
	assert_almost_eq(
		attacks.charge_duration(),
		ContextualAttackController.MAX_CHARGE_SECONDS,
		0.0001
	)
	assert_almost_eq(attacks.charge_progress(), 1.0, 0.0001)
	assert_almost_eq(attacks.charge_damage_multiplier(), 2.0, 0.0001)
	assert_true(attacks.release_charge())
	assert_almost_eq(attacks.current_spec.actor_damage, 360.0, 0.001)
	assert_almost_eq(attacks.current_spec.structural_damage, 360.0, 0.001)
	assert_almost_eq(attacks.current_spec.impulse_per_mass, 1020.0, 0.001)
	_record_test_execution()


func test_full_charge_ground_commit_emits_double_damage_with_base_impulse_and_radius() -> void:
	var city: CitySlice = await _city()
	var attacks: ContextualAttackController = city.contextual_attacks
	var payloads: Array[Dictionary] = []
	city.robot.heavy_impact_requested.connect(
		func(
			origin: Vector2,
			radius: float,
			actor_damage: float,
			structural_damage: float,
			impulse_per_mass: float,
			attack_id: int
		) -> void:
			payloads.append({
				"origin": origin,
				"radius": radius,
				"actor_damage": actor_damage,
				"structural_damage": structural_damage,
				"impulse_per_mass": impulse_per_mass,
				"attack_id": attack_id,
			})
	)
	_tune_short_attack(attacks.resolver)
	var attack_id: int = attacks.begin_charge()
	attacks._process(2.5)
	assert_true(attacks.release_charge())
	await get_tree().create_timer(attacks.current_spec.anticipation_seconds + 0.03).timeout
	assert_eq(payloads.size(), 1)
	assert_eq(int(payloads[0].attack_id), attack_id)
	assert_almost_eq(float(payloads[0].actor_damage), 360.0, 0.001)
	assert_almost_eq(float(payloads[0].structural_damage), 360.0, 0.001)
	assert_almost_eq(float(payloads[0].impulse_per_mass), 1020.0, 0.001)
	assert_almost_eq(float(payloads[0].radius), 320.0, 0.001)
	_record_test_execution()


func test_half_charge_freezes_robot_then_release_deals_150_percent_jab_damage() -> void:
	var city: CitySlice = await _city()
	var robot: GiantRobotController = city.robot
	var attacks: ContextualAttackController = city.contextual_attacks
	robot.global_position = Vector2(900.0, 460.0)
	robot.velocity.x = robot.max_speed
	city.car.freeze = true
	city.car.global_position = robot.global_position + Vector2(135.0, 95.0)
	city.car.current_health = 500.0
	assert_gt(attacks.begin_charge(), 0)
	assert_true(attacks.current_spec.is_jab_cross())
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.ATTACK_LOCKED)
	var locked_x: float = robot.global_position.x
	attacks._process(1.0)
	robot.physics_step(-1.0, 1.0)
	assert_almost_eq(robot.global_position.x, locked_x, 0.001)
	assert_almost_eq(attacks.charge_damage_multiplier(), 1.5, 0.0001)
	assert_true(attacks.release_charge())
	var charged_spec: AttackSpec = attacks.current_spec
	assert_almost_eq(charged_spec.actor_damage, 217.5, 0.001)
	assert_almost_eq(charged_spec.structural_damage, 187.5, 0.001)
	assert_almost_eq(charged_spec.impulse_per_mass, 1080.0, 0.001)
	await get_tree().create_timer(charged_spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	assert_almost_eq(city.car.current_health, 282.5, 0.01)
	assert_eq(attacks.jab_cross_impact.last_accepted_targets, 1)
	_record_test_execution()


func test_airborne_charge_freezes_vertical_and_horizontal_motion_until_release() -> void:
	var city: CitySlice = await _city()
	var robot: GiantRobotController = city.robot
	var attacks: ContextualAttackController = city.contextual_attacks
	robot.global_position = Vector2(760.0, 240.0)
	robot.velocity = Vector2(310.0, -420.0)
	var locked_position: Vector2 = robot.global_position
	assert_gt(attacks.begin_charge(), 0)
	robot.physics_step(1.0, 0.5)
	assert_eq(robot.global_position, locked_position)
	assert_eq(robot.velocity, Vector2.ZERO)
	attacks._process(1.0)
	robot.physics_step(-1.0, 0.5)
	assert_eq(robot.global_position, locked_position)
	assert_eq(robot.velocity, Vector2.ZERO)
	assert_true(attacks.release_charge())
	robot.physics_step(0.0, 0.1)
	assert_gt(robot.global_position.y, locked_position.y)
	_record_test_execution()


func test_attack_locks_horizontal_movement_through_telegraph_and_recovery() -> void:
	var city: CitySlice = await _city()
	city.robot.velocity.x = city.robot.max_speed * 0.8
	var attack_id: int = city.robot.request_attack()
	var spec: AttackSpec = city.contextual_attacks.current_spec
	var locked_position_x: float = city.robot.position.x
	assert_gt(attack_id, 0)
	assert_true(spec.is_jab_cross())
	assert_true(city.contextual_attacks.is_busy())
	assert_eq(
		city.robot.locomotion_state,
		GiantRobotController.LocomotionState.ATTACK_LOCKED
	)
	assert_almost_eq(city.robot.velocity.x, 0.0, 0.001)
	city.robot.physics_step(-1.0, 0.1)
	assert_almost_eq(city.robot.position.x, locked_position_x, 0.001)
	await get_tree().create_timer(spec.anticipation_seconds + spec.active_seconds + 0.03).timeout
	assert_true(city.contextual_attacks.is_busy())
	assert_eq(
		city.robot.locomotion_state,
		GiantRobotController.LocomotionState.ATTACK_LOCKED
	)
	city.robot.physics_step(1.0, 0.1)
	assert_almost_eq(city.robot.position.x, locked_position_x, 0.001)
	await get_tree().create_timer(spec.recovery_seconds + 0.03).timeout
	assert_false(city.contextual_attacks.is_busy())
	assert_eq(city.robot.locomotion_state, GiantRobotController.LocomotionState.IDLE)
	city.robot.physics_step(1.0, 0.1)
	assert_gt(city.robot.position.x, locked_position_x)
	_record_test_execution()


func test_jab_cross_commits_forward_and_leaves_rear_target_untouched() -> void:
	var city: CitySlice = await _city()
	city.robot.position = Vector2(900.0, 460.0)
	city.robot.facing = 1
	city.robot.velocity.x = city.robot.max_speed * 0.80
	city.car.freeze = true
	city.car.global_position = city.robot.global_position + Vector2(135.0, 95.0)
	city.car.current_health = 1.0
	city.streetlamp.global_position = city.robot.global_position + Vector2(-100.0, 20.0)
	city.streetlamp.current_health = 1.0
	var attack_id: int = city.robot.request_attack()
	var spec: AttackSpec = city.contextual_attacks.current_spec
	assert_true(spec.is_jab_cross())
	assert_eq(city.gameplay_hud.objective_label.text, "JAB-CROSS LOCKED / FORWARD IMPACT")
	city.robot.velocity.x = -city.robot.max_speed
	city.robot.facing = -1
	await get_tree().create_timer(spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	assert_eq(
		city.gameplay_hud.objective_label.text,
		"JAB-CROSS PUNCH / MOMENTUM TRANSFERRED"
	)
	assert_true(city.car.is_broken)
	assert_false(city.streetlamp.is_broken)
	assert_eq(city.contextual_attacks.jab_cross_impact.last_accepted_targets, 1)
	assert_almost_eq(
		city.contextual_attacks.jab_cross_impact.last_velocity_retention,
		0.92,
		0.001
	)
	assert_almost_eq(city.robot.velocity.x, 0.0, 0.001)
	assert_gt(attack_id, 0)
	_record_test_execution()


func test_jab_cross_concrete_drags_and_steel_requires_two_hits() -> void:
	var concrete_city: CitySlice = await _city()
	var concrete_cell: Destructible2D = concrete_city.building.get_cell(1, 1)
	concrete_city.robot.global_position = Vector2(1325.0, 460.0)
	concrete_city.robot.facing = 1
	concrete_city.robot.velocity.x = 200.0
	var concrete_spec: AttackSpec = _jab_cross_spec(9101)
	assert_eq(
		concrete_city.contextual_attacks.jab_cross_impact.resolve(
			concrete_spec,
			concrete_city.robot
		),
		1
	)
	assert_true(concrete_cell.is_destroyed())
	assert_almost_eq(concrete_city.robot.velocity.x, 144.0, 0.01)
	concrete_city.queue_free()
	await get_tree().process_frame
	var steel_city: CitySlice = await _city()
	var steel_cell: Destructible2D = steel_city.building.get_cell(2, 1)
	steel_city.robot.global_position = Vector2(1490.0, 460.0)
	steel_city.robot.facing = 1
	steel_city.robot.velocity.x = 200.0
	assert_eq(
		steel_city.contextual_attacks.jab_cross_impact.resolve(
			_jab_cross_spec(9102),
			steel_city.robot
		),
		1
	)
	assert_false(steel_cell.is_destroyed())
	assert_almost_eq(steel_cell.current_health, 30.0, 0.01)
	assert_almost_eq(steel_city.robot.velocity.x, -12.0, 0.01)
	assert_almost_eq(
		steel_city.contextual_attacks.jab_cross_impact.last_velocity_retention,
		-0.06,
		0.001
	)
	steel_city.robot.velocity.x = 200.0
	assert_eq(
		steel_city.contextual_attacks.jab_cross_impact.resolve(
			_jab_cross_spec(9103),
			steel_city.robot
		),
		1
	)
	assert_true(steel_cell.is_destroyed())
	assert_almost_eq(steel_city.robot.velocity.x, 76.0, 0.01)
	assert_almost_eq(
		steel_city.contextual_attacks.jab_cross_impact.last_velocity_retention,
		0.38,
		0.001
	)
	_record_test_execution()


func test_enemy_projectiles_damage_intact_building_cells() -> void:
	var city: CitySlice = await _city()
	var glass_cell: Destructible2D = city.building.get_cell(0, 1)
	city.soldier.request_projectile(
		Vector2(1100.0, glass_cell.global_position.y),
		Vector2.RIGHT,
		720.0,
		7.0,
		&"bullet"
	)
	for physics_index: int in range(30):
		await get_tree().physics_frame
	assert_almost_eq(glass_cell.current_health, glass_cell.max_health - 7.0, 0.01)
	assert_false(glass_cell.is_destroyed())
	_record_test_execution()


func test_space_during_recovery_remains_attack_only() -> void:
	var city: CitySlice = await _city()
	_tune_short_attack(city.contextual_attacks.resolver)
	assert_gt(city.robot.request_attack(), 0)
	await _wait_for_phase(city.contextual_attacks, ContextualAttackController.Phase.RECOVERY)
	assert_eq(city.robot.request_attack(), 0)
	assert_eq(city.contextual_attacks.buffered_dodge_count, 0)
	await get_tree().create_timer(0.08).timeout
	assert_eq(city.robot.dodge_count, 0)
	assert_eq(city.robot.locomotion_state, GiantRobotController.LocomotionState.IDLE)


func test_melee_cancels_dodge_into_half_momentum_attack_in_dodge_direction() -> void:
	var city: CitySlice = await _city()
	var robot: GiantRobotController = city.robot
	var attacks: ContextualAttackController = city.contextual_attacks
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	_tune_short_attack(attacks.resolver)
	robot.global_position = Vector2(900.0, 460.0)
	robot.collision_mask = 0
	robot.gravity = 0.0
	city.car.freeze = true
	city.car.global_position = robot.global_position + Vector2(-135.0, 95.0)
	city.car.current_health = 1.0
	city.streetlamp.global_position = robot.global_position + Vector2(100.0, 20.0)
	city.streetlamp.current_health = 1.0
	assert_true(robot._start_dodge(-1))
	assert_true(presenter.dodging)
	var spent_cooldown: float = robot.dodge_cooldown_remaining
	var attack_id: int = robot.request_attack()
	var spec: AttackSpec = attacks.current_spec
	assert_gt(attack_id, 0)
	assert_true(spec.is_jab_cross())
	assert_eq(spec.facing, -1)
	assert_almost_eq(spec.speed_ratio, 0.50, 0.0001)
	assert_almost_eq(spec.actor_damage, 72.5, 0.001)
	assert_almost_eq(spec.structural_damage, 62.5, 0.001)
	assert_almost_eq(spec.impulse_per_mass, 540.0, 0.001)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.ATTACK_LOCKED)
	assert_almost_eq(robot.velocity.x, 0.0, 0.001)
	assert_almost_eq(robot.dodge_cooldown_remaining, spent_cooldown, 0.001)
	assert_false(robot.dodge_invulnerable)
	assert_false(presenter.dodging)
	assert_true(presenter.attacking)
	await get_tree().create_timer(spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	assert_true(city.car.is_broken)
	assert_false(city.streetlamp.is_broken)
	assert_eq(attacks.jab_cross_impact.last_accepted_targets, 1)
	_record_test_execution()


func test_space_binding_cancels_east_dodge_into_half_momentum_melee() -> void:
	var city: CitySlice = await _city()
	var robot: GiantRobotController = city.robot
	_tune_short_attack(city.contextual_attacks.resolver)
	robot.collision_mask = 0
	robot.gravity = 0.0
	var space_press: InputEventKey = InputEventKey.new()
	space_press.physical_keycode = KEY_SPACE
	space_press.pressed = true
	assert_true(InputMap.event_is_action(space_press, &"stomp"))
	assert_true(robot._start_dodge(1))
	assert_gt(robot.begin_attack_charge(), 0)
	assert_true(city.contextual_attacks.is_charging())
	city.contextual_attacks._process(1.0)
	assert_true(robot.release_attack_charge())
	var spec: AttackSpec = city.contextual_attacks.current_spec
	assert_not_null(spec)
	if spec == null:
		return
	assert_true(spec.is_jab_cross())
	assert_eq(spec.facing, 1)
	assert_almost_eq(spec.speed_ratio, 0.50, 0.0001)
	assert_almost_eq(spec.actor_damage, 108.75, 0.001)
	assert_almost_eq(spec.structural_damage, 93.75, 0.001)
	assert_almost_eq(spec.impulse_per_mass, 540.0, 0.001)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.ATTACK_LOCKED)
	assert_false(robot.dodge_invulnerable)
	_record_test_execution()


func test_recovery_double_tap_buffers_directional_dodge_with_300ms_invulnerability() -> void:
	var city: CitySlice = await _city()
	city.robot.global_position = Vector2(400.0, 460.0)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	city.robot.facing = -1
	_tune_short_attack(city.contextual_attacks.resolver)
	assert_gt(city.robot.request_attack(), 0)
	assert_eq(
		city.robot.locomotion_state,
		GiantRobotController.LocomotionState.ATTACK_LOCKED
	)
	await _wait_for_phase(city.contextual_attacks, ContextualAttackController.Phase.RECOVERY)
	assert_false(city.robot._register_move_tap(-1))
	assert_true(city.robot._register_move_tap(-1))
	assert_eq(city.contextual_attacks.buffered_dodge_count, 1)
	await get_tree().create_timer(0.08).timeout
	assert_eq(city.robot.locomotion_state, GiantRobotController.LocomotionState.DODGE)
	assert_eq(city.robot.dodge_count, 1)
	assert_true(city.robot.dodge_invulnerable)
	assert_false(city.robot.dodge_ready)
	assert_almost_eq(city.robot.dodge_cooldown_remaining, 1.20, 0.025)
	assert_almost_eq(city.robot.dodge_invulnerability_remaining, 0.30, 0.025)
	var start_x: float = city.robot.global_position.x
	city.robot.physics_step(0.0, 0.05)
	assert_lt(city.robot.global_position.x, start_x)
	var health_before: float = city.robot.current_health
	assert_false(city.robot.receive_damage(DamageEvent.new(8801, null, 40.0)))
	assert_eq(city.robot.current_health, health_before)
	assert_eq(city.robot.invulnerable_rejection_count, 1)
	city.robot.physics_step(0.0, 0.20)
	assert_true(city.robot.dodge_invulnerable)
	city.robot.physics_step(0.0, 0.06)
	assert_false(city.robot.dodge_invulnerable)
	assert_false(city.robot._start_dodge())
	assert_true(city.robot.receive_damage(DamageEvent.new(8802, null, 40.0)))
	assert_eq(city.robot.current_health, health_before - 40.0)
	city.robot.physics_step(0.0, 0.90)
	assert_true(city.robot.dodge_ready)
	assert_eq(city.robot.dodge_cooldown_remaining, 0.0)


func test_same_direction_double_tap_dodges_left_and_right() -> void:
	var city: CitySlice = await _city()
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	assert_false(city.robot._register_move_tap(1))
	assert_true(city.robot._register_move_tap(1))
	assert_eq(city.robot.facing, 1)
	assert_eq(city.robot.dodge_count, 1)
	city.robot.physics_step(0.0, city.robot.dodge_duration + 0.01)
	city.robot.physics_step(0.0, city.robot.dodge_cooldown_seconds)
	assert_false(city.robot._register_move_tap(1))
	assert_false(city.robot._register_move_tap(-1))
	assert_eq(city.robot.dodge_count, 1)
	assert_true(city.robot._register_move_tap(-1))
	assert_eq(city.robot.facing, -1)
	assert_eq(city.robot.dodge_count, 2)


func test_movement_releases_on_first_step_after_attack_recovery() -> void:
	var city: CitySlice = await _city()
	city.robot.global_position = Vector2(80.0, 460.0)
	_tune_short_attack(city.contextual_attacks.resolver)
	assert_gt(city.robot.request_attack(), 0)
	await _wait_for_phase(city.contextual_attacks, ContextualAttackController.Phase.READY)
	assert_false(city.contextual_attacks.is_busy())
	assert_eq(city.contextual_attacks.phase, ContextualAttackController.Phase.READY)
	city.robot.physics_step(1.0, 1.0 / 60.0)
	assert_eq(city.robot.locomotion_state, GiantRobotController.LocomotionState.WALK)
	assert_gt(city.robot.velocity.x, 0.0)


func _jab_cross_spec(attack_id: int) -> AttackSpec:
	return AttackSpec.new(
		AttackSpec.Mode.JAB_CROSS,
		attack_id,
		1,
		0.8,
		0.055,
		0.10,
		0.14,
		145.0,
		125.0,
		1080.0,
		Vector2(190.0, 150.0),
		Vector2(105.0, 62.0)
	)


func _tune_short_attack(resolver: AttackResolver) -> void:
	resolver.ground_anticipation_seconds = 0.01
	resolver.ground_active_seconds = 0.01
	resolver.ground_recovery_seconds = 0.04
	resolver.jab_cross_anticipation_seconds = 0.01
	resolver.jab_cross_active_seconds = 0.01
	resolver.jab_cross_recovery_seconds = 0.04


func _wait_for_phase(controller: ContextualAttackController, expected: int) -> void:
	for frame_index: int in range(20):
		if controller.phase == expected:
			return
		await get_tree().process_frame
	assert_eq(controller.phase, expected)


func _city() -> CitySlice:
	_release_test_actions()
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	city.robot.set_physics_process(false)
	await get_tree().process_frame
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.set_physics_process(false)
	return city


func _release_test_actions() -> void:
	for action: StringName in [&"move_left", &"move_right", &"stomp", &"dodge"]:
		Input.action_release(action)


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))

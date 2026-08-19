extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


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
	assert_gt(city.robot.velocity.x, city.robot.max_speed * 0.55)
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


func _city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.set_physics_process(false)
	return city


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))

extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func test_resolver_locks_ground_at_699_and_drive_at_700() -> void:
	var resolver: AttackResolver = AttackResolver.new()
	add_child_autofree(resolver)
	var ground: AttackSpec = resolver.resolve(1, 1, 0.699, 180.0, 1020.0, 320.0)
	var drive: AttackSpec = resolver.resolve(2, -1, 0.700, 180.0, 1020.0, 320.0)
	assert_true(ground.is_ground_smash())
	assert_eq(ground.facing, 1)
	assert_almost_eq(ground.speed_ratio, 0.699, 0.0001)
	assert_true(drive.is_shoulder_drive())
	assert_eq(drive.facing, -1)
	assert_almost_eq(drive.speed_ratio, 0.700, 0.0001)
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
	assert_eq(city.contextual_attacks.drive_impact.last_accepted_targets, 0)
	_record_test_execution()


func test_shoulder_drive_hits_front_target_once_and_leaves_rear_target_untouched() -> void:
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
	assert_true(spec.is_shoulder_drive())
	city.robot.velocity.x = city.robot.max_speed * 0.20
	city.robot.facing = -1
	await get_tree().create_timer(spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	assert_true(city.car.is_broken)
	assert_false(city.streetlamp.is_broken)
	assert_eq(city.contextual_attacks.drive_impact.last_accepted_targets, 1)
	assert_almost_eq(
		city.contextual_attacks.drive_impact.last_velocity_retention,
		0.88,
		0.001
	)
	assert_gt(attack_id, 0)
	_record_test_execution()


func test_shoulder_drive_concrete_slows_and_steel_stops_charge() -> void:
	var concrete_city: CitySlice = await _city()
	var concrete_cell: Destructible2D = concrete_city.building.get_cell(1, 1)
	concrete_city.robot.global_position = Vector2(1325.0, 460.0)
	concrete_city.robot.facing = 1
	concrete_city.robot.velocity.x = 200.0
	var concrete_spec: AttackSpec = AttackSpec.new(
		AttackSpec.Mode.SHOULDER_DRIVE,
		9101,
		1,
		0.8,
		0.0,
		0.12,
		0.18,
		130.0,
		180.0,
		920.0,
		Vector2(190.0, 150.0),
		Vector2(105.0, 62.0)
	)
	assert_eq(
		concrete_city.contextual_attacks.drive_impact.resolve(
			concrete_spec,
			concrete_city.robot
		),
		1
	)
	assert_true(concrete_cell.is_destroyed())
	assert_almost_eq(concrete_city.robot.velocity.x, 140.0, 0.01)
	concrete_city.queue_free()
	await get_tree().process_frame
	var steel_city: CitySlice = await _city()
	var steel_cell: Destructible2D = steel_city.building.get_cell(2, 1)
	steel_city.robot.global_position = Vector2(1490.0, 460.0)
	steel_city.robot.facing = 1
	steel_city.robot.velocity.x = 200.0
	var steel_spec: AttackSpec = AttackSpec.new(
		AttackSpec.Mode.SHOULDER_DRIVE,
		9102,
		1,
		0.8,
		0.0,
		0.12,
		0.18,
		130.0,
		180.0,
		920.0,
		Vector2(190.0, 150.0),
		Vector2(105.0, 62.0)
	)
	assert_eq(
		steel_city.contextual_attacks.drive_impact.resolve(steel_spec, steel_city.robot),
		1
	)
	assert_true(steel_cell.is_destroyed())
	assert_almost_eq(steel_city.robot.velocity.x, 60.0, 0.01)
	_record_test_execution()


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

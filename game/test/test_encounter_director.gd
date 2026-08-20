extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const CONTACT: EnemyWave = preload("res://resources/encounters/wave_01_contact.tres")
const ARMOR: EnemyWave = preload("res://resources/encounters/wave_02_armor.tres")
const AIR: EnemyWave = preload("res://resources/encounters/wave_03_air.tres")
const RETALIATION: EnemyWave = preload("res://resources/encounters/wave_04_retaliation.tres")


func test_runtime_prewarms_exact_enemy_caps_without_post_warm_creation() -> void:
	var city: CitySlice = await _spawn_city()
	assert_eq(city.encounter_runtime.total_count(&"soldier"), 12)
	assert_eq(city.encounter_runtime.total_count(&"tank"), 2)
	assert_eq(city.encounter_runtime.total_count(&"helicopter"), 1)
	assert_eq(city.encounter_runtime.family_capacity(&"infantry"), 12)
	assert_eq(city.encounter_runtime.family_capacity(&"light"), 3)
	assert_eq(city.encounter_runtime.family_capacity(&"heavy"), 4)
	assert_eq(city.encounter_runtime.family_capacity(&"air"), 4)
	assert_eq(city.encounter_runtime.family_capacity(&"siege"), 2)
	assert_eq(
		city.encounter_runtime.total_count(),
		RuntimeBudget.SOLDIERS
		+ RuntimeBudget.TANKS
		+ RuntimeBudget.HELICOPTERS
		+ RuntimeBudget.PROCEDURAL_ENEMIES
	)
	assert_eq(city.encounter_runtime.post_warm_creation_count, 0)


func test_all_regular_soldiers_share_exact_pixel_height_and_face_the_player() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	for soldier_index: int in range(city.encounter_runtime.soldiers.size()):
		var soldier: SoldierEnemy = city.encounter_runtime.acquire(
			&"soldier",
			Vector2(980.0 + float(soldier_index) * 40.0, 542.5)
		) as SoldierEnemy
		assert_not_null(soldier)
		var rendered_height: float = (
			soldier.visual.texture.get_size().y * absf(soldier.visual.scale.y)
		)
		assert_almost_eq(
			rendered_height,
			EncounterRuntime.SOLDIER_RENDER_HEIGHT_PIXELS,
			0.001
		)
		assert_eq(soldier.facing, -1)
		assert_false(soldier.visual.flip_h)
		assert_eq(soldier.bounce_squash, 0.0)
		soldier.velocity.x = soldier.move_speed
		soldier.update_movement_bounce(0.11 + float(soldier_index) * 0.02)
		var animated_height: float = (
			soldier.visual.texture.get_size().y * absf(soldier.visual.scale.y)
		)
		assert_almost_eq(
			animated_height,
			EncounterRuntime.SOLDIER_RENDER_HEIGHT_PIXELS,
			0.001
		)
	var tracked: SoldierEnemy = city.encounter_runtime.soldiers[0]
	tracked.state = SoldierEnemy.State.ANTICIPATE
	city.robot.global_position.x = tracked.global_position.x + 200.0
	tracked._physics_process(0.0)
	assert_eq(tracked.facing, 1)
	assert_true(tracked.visual.flip_h)
	city.robot.global_position.x = tracked.global_position.x - 200.0
	tracked._physics_process(0.0)
	assert_eq(tracked.facing, -1)
	assert_false(tracked.visual.flip_h)


func test_projectile_pool_is_partitioned_16_4_4_and_reservations_are_strict() -> void:
	var city: CitySlice = await _spawn_city()
	var pool: ProjectilePool = city.projectile_root
	assert_eq(pool.partition_capacity(&"bullet"), 16)
	assert_eq(pool.partition_capacity(&"shell"), 4)
	assert_eq(pool.partition_capacity(&"rocket"), 4)
	assert_eq(pool.partition_capacity(&"player_bullet"), 8)
	assert_eq(pool.total_count(), 32)
	var reservation: int = pool.reserve(&"shell")
	assert_gt(reservation, 0)
	for shell_index: int in range(3):
		assert_not_null(_acquire_test_projectile(pool, &"shell", city.soldier))
	assert_null(_acquire_test_projectile(pool, &"shell", city.soldier))
	assert_not_null(pool.acquire_reserved(
		reservation,
		Vector2.ZERO,
		Vector2.RIGHT,
		400.0,
		10.0,
		city.soldier,
		CitySlice.ROBOT_LAYER,
		&"shell"
	))
	assert_eq(pool.active_count(&"shell"), 4)


func test_authored_waves_match_approved_compositions() -> void:
	assert_eq(_counts(CONTACT), {"soldier": 4, "tank": 0, "helicopter": 0})
	assert_eq(_counts(ARMOR), {"soldier": 6, "tank": 1, "helicopter": 0})
	assert_eq(_counts(AIR), {"soldier": 8, "tank": 1, "helicopter": 1})
	assert_eq(_counts(RETALIATION), {"soldier": 12, "tank": 2, "helicopter": 1})


func test_wave_progression_waits_for_active_enemies_then_advances() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	var director: EncounterDirector = city.encounter_director
	director.setup(city.encounter_runtime, [CONTACT, ARMOR])
	director.start()
	director._process(2.4)
	assert_eq(director.phase_index, 0)
	assert_eq(city.encounter_runtime.active_count(&"soldier"), 3)
	director._process(0.2)
	assert_eq(city.encounter_runtime.active_count(&"soldier"), 4)
	director._process(8.0)
	assert_eq(director.phase_index, 0)
	city.encounter_runtime.release_all()
	director._process(1.1)
	assert_eq(director.phase_index, 1)
	assert_eq(director.current_phase_name(), "encounter.armor_response")


func test_tank_warning_fires_exact_snapshot_from_reserved_slot() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	var tank: TankEnemy = city.encounter_runtime.acquire(
		&"tank",
		Vector2(1300.0, 551.0)
	) as TankEnemy
	var origin: Vector2 = Vector2(1320.0, 500.0)
	var target: Vector2 = Vector2(900.0, 570.0)
	assert_true(tank.begin_telegraph(&"shell", 0.75, origin, target))
	assert_eq(city.projectile_root.reservation_count(&"shell"), 1)
	assert_eq(city.telegraph_presenter.active_count(), 1)
	assert_false(tank.advance_telegraph(0.74))
	assert_true(tank.advance_telegraph(0.01))
	tank._fire_snapshot()
	var shell: Projectile2D = city.projectile_root.last_acquired
	assert_not_null(shell)
	assert_eq(shell.global_position, origin)
	assert_almost_eq(shell.velocity.normalized().dot(origin.direction_to(target)), 1.0, 0.001)
	assert_eq(city.projectile_root.reservation_count(&"shell"), 0)
	assert_eq(city.telegraph_presenter.active_count(), 0)


func test_warning_and_reservation_cancel_atomically_on_reuse() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	var helicopter: HelicopterEnemy = city.encounter_runtime.acquire(
		&"helicopter",
		Vector2(1500.0, 180.0)
	) as HelicopterEnemy
	assert_true(helicopter.begin_telegraph(
		&"rocket",
		0.9,
		helicopter.global_position,
		city.robot.global_position
	))
	assert_eq(city.projectile_root.reservation_count(&"rocket"), 1)
	assert_eq(city.telegraph_presenter.active_count(), 1)
	city.encounter_runtime.release(helicopter)
	assert_eq(city.projectile_root.reservation_count(&"rocket"), 0)
	assert_eq(city.telegraph_presenter.active_count(), 0)
	assert_eq(city.telegraph_presenter.get_child_count(), 0)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _acquire_test_projectile(
	pool: ProjectilePool,
	kind: StringName,
	source: Node
) -> Projectile2D:
	return pool.acquire(
		Vector2.ZERO,
		Vector2.RIGHT,
		400.0,
		10.0,
		source,
		CitySlice.ROBOT_LAYER,
		kind
	)


func _counts(wave: EnemyWave) -> Dictionary:
	var counts: Dictionary = {"soldier": 0, "tank": 0, "helicopter": 0}
	for spawn: EnemySpawnEntry in wave.spawns:
		counts[spawn.kind] += EnemyArchetypeCatalog.spawn_multiplier(spawn.kind)
	return counts

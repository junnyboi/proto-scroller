extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const CONTACT: EnemyWave = preload("res://resources/encounters/wave_01_contact.tres")
const ARMOR: EnemyWave = preload("res://resources/encounters/wave_02_armor.tres")
const AIR: EnemyWave = preload("res://resources/encounters/wave_03_air.tres")
const RETALIATION: EnemyWave = preload("res://resources/encounters/wave_04_retaliation.tres")


func test_runtime_prewarms_exact_enemy_caps_without_post_warm_creation() -> void:
	var city: CitySlice = await _spawn_city()
	assert_eq(city.encounter_runtime.total_count(&"soldier"), 24)
	assert_eq(city.encounter_runtime.total_count(&"tank"), 4)
	assert_eq(city.encounter_runtime.total_count(&"helicopter"), 2)
	assert_eq(city.encounter_runtime.family_capacity(&"infantry"), 24)
	assert_eq(city.encounter_runtime.family_capacity(&"light"), 6)
	assert_eq(city.encounter_runtime.family_capacity(&"heavy"), 8)
	assert_eq(city.encounter_runtime.family_capacity(&"air"), 8)
	assert_eq(city.encounter_runtime.family_capacity(&"siege"), 4)
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
	assert_eq(tracked.facing, -1)
	assert_false(tracked.visual.flip_h)
	tracked.state = SoldierEnemy.State.AIM
	tracked._physics_process(0.0)
	assert_eq(tracked.facing, 1)
	assert_true(tracked.visual.flip_h)
	tracked.state = SoldierEnemy.State.ANTICIPATE
	city.robot.global_position.x = tracked.global_position.x - 200.0
	tracked._physics_process(0.0)
	assert_eq(tracked.facing, 1)
	assert_true(tracked.visual.flip_h)


func test_base_tank_uses_exact_double_ground_vehicle_geometry() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	var tank: TankEnemy = city.encounter_runtime.acquire(
		&"tank",
		Vector2(1180.0, 551.0)
	) as TankEnemy
	assert_not_null(tank)
	var rendered_size: Vector2 = tank.visual.texture.get_size() * tank.visual.scale.abs()
	var texture_size: Vector2 = tank.visual.texture.get_size()
	var display_bounds: Vector2 = Vector2(470.0, 200.0)
	var expected_fit: float = minf(
		display_bounds.x / texture_size.x,
		display_bounds.y / texture_size.y
	)
	assert_eq(rendered_size, texture_size * expected_fit)
	var body: RectangleShape2D = (
		tank.get_node(^"CollisionShape2D").shape as RectangleShape2D
	)
	assert_eq(body.size, Vector2(440.0, 156.0))
	var hurtbox: RectangleShape2D = (
		tank.get_node(^"Hurtbox/CollisionShape2D").shape as RectangleShape2D
	)
	assert_eq(hurtbox.size, Vector2(492.8, 174.72))


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
	assert_eq(director.pending_count(), 8)
	director._process(1.2)
	assert_eq(director.phase_index, 0)
	assert_eq(city.encounter_runtime.active_count(&"soldier"), 4)
	director._process(0.15)
	assert_eq(city.encounter_runtime.active_count(&"soldier"), 7)
	director._process(0.04)
	assert_eq(city.encounter_runtime.active_count(&"soldier"), 8)
	director._process(8.0)
	assert_eq(director.phase_index, 0)
	city.encounter_runtime.release_all()
	director._process(0.6)
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
	var damage_output: float = (
		tank.shell_damage * tank.projectile_damage_multiplier * tank.aura_damage_multiplier
	)
	assert_true(tank.begin_telegraph(&"shell", 0.75, origin, target, damage_output))
	assert_eq(city.projectile_root.reservation_count(&"shell"), 1)
	assert_eq(city.telegraph_presenter.active_count(), 1)
	var warning: Dictionary = city.telegraph_presenter.snapshot(tank._telegraph_id)
	assert_eq(warning.origin, tank.visual.global_position)
	assert_ne(warning.origin, origin)
	assert_eq(tank.telegraph_origin(), origin)
	assert_almost_eq(
		float(warning.thickness_scale),
		tank.attack_telegraph_thickness_scale(),
		0.001
	)
	assert_gt(float(warning.thickness_scale), 2.0)
	assert_almost_eq(
		float(warning.color_intensity),
		tank.attack_telegraph_color_intensity(damage_output),
		0.001
	)
	assert_gt(float(warning.color_intensity), 1.0)
	var base_intensity: float = tank.attack_telegraph_color_intensity(damage_output)
	tank.cycle_attack_multiplier = 2.0
	assert_gt(tank.attack_telegraph_color_intensity(damage_output), base_intensity)
	tank.cycle_attack_multiplier = 1.0
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


func test_ground_vehicle_uses_visible_bottom_and_center_for_presentation() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	var jackal: ProceduralEnemy = city.encounter_runtime.acquire(
		&"jackal",
		Vector2(1200.0, 554.0)
	) as ProceduralEnemy
	assert_not_null(jackal)
	var content_rect: Rect2 = jackal.visual.get_meta(
		EnemyActor2D.VISUAL_CONTENT_RECT_META
	)
	assert_lt(content_rect.end.y, jackal.visual.texture.get_size().y * 0.5)
	var visible_bottom_y: float = jackal.visual.to_global(
		Vector2(content_rect.get_center().x, content_rect.end.y)
	).y
	assert_almost_eq(
		visible_bottom_y,
		EncounterRuntime.LAND_ENEMY_VISUAL_BASELINE_Y,
		0.01
	)
	var visible_center: Vector2 = jackal.attack_telegraph_origin()
	assert_ne(visible_center, jackal.visual.global_position)
	assert_eq(visible_center, jackal.visual.to_global(content_rect.get_center()))
	assert_true(jackal.begin_telegraph(
		&"bullet",
		0.5,
		jackal.global_position,
		city.robot.global_position,
		6.0
	))
	var warning: Dictionary = city.telegraph_presenter.snapshot(jackal._telegraph_id)
	assert_eq(warning.origin, visible_center)
	jackal.cancel_telegraph()


func test_humanoid_telegraphs_use_visible_grounded_center() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	var humanoid_ids: Array[StringName] = [
		&"soldier", &"bulwark", &"lobber", &"sapper", &"lancer",
		&"covenant_warden", &"intake_shepherd", &"memorial_usher",
		&"suture_marshal", &"privy_chirurgeon",
	]
	for archetype_id: StringName in humanoid_ids:
		var enemy: EnemyActor2D = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(1080.0, 200.0)
		)
		assert_not_null(enemy, archetype_id)
		enemy.set_physics_process(false)
		var content_rect: Rect2 = enemy.visual.get_meta(
			EnemyActor2D.VISUAL_CONTENT_RECT_META
		)
		var local_ground_center: Vector2 = Vector2(
			content_rect.get_center().x * (-1.0 if enemy.visual.flip_h else 1.0),
			content_rect.end.y
		)
		var expected_origin: Vector2 = enemy.visual.to_global(local_ground_center)
		var projectile_muzzle: Vector2 = enemy.global_position + Vector2(31.0, -17.0)
		assert_true(enemy.begin_telegraph(
			&"bullet",
			0.5,
			projectile_muzzle,
			city.robot.global_position,
			6.0
		), archetype_id)
		var warning: Dictionary = city.telegraph_presenter.snapshot(enemy._telegraph_id)
		assert_eq(warning.origin, expected_origin, archetype_id)
		assert_almost_eq(
			float(warning.origin.y),
			EncounterRuntime.LAND_ENEMY_VISUAL_BASELINE_Y,
			0.01,
			archetype_id
		)
		assert_eq(enemy.telegraph_origin(), projectile_muzzle, archetype_id)
		city.encounter_runtime.release(enemy)


func test_warning_pulse_accelerates_and_extreme_threats_shift_red_white() -> void:
	var city: CitySlice = await _spawn_city()
	var presenter: TelegraphPresenter2D = city.telegraph_presenter
	assert_almost_eq(presenter.firing_pulse_amplitude(0.0), 0.04, 0.001)
	assert_almost_eq(presenter.firing_pulse_amplitude(1.0), 0.32, 0.001)
	assert_gt(presenter.firing_pulse_brightness(1.0), 1.30)
	var attack_color: Color = Color(1.0, 0.35, 0.12, 0.72)
	var standard: Color = presenter.threat_color(attack_color, 1.0, 1.0)
	var extreme: Color = presenter.threat_color(
		attack_color,
		EnemyActor2D.TELEGRAPH_MAXIMUM_COLOR_INTENSITY,
		1.0
	)
	assert_gt(extreme.g, standard.g)
	assert_gt(extreme.b, standard.b)
	assert_gt(extreme.r, 0.99)


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

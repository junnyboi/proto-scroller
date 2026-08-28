extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_rank_zero_and_tap_charge_capture_nothing() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	var debris: DebrisBody2D = _spawn_debris(city, Vector2(80.0, 0.0))
	var spec: AttackSpec = _attack(41_001)
	runtime.call(&"_on_charge_started", spec)
	runtime.call(&"_on_charge_updated", spec, 0.8, 0.4, 1.4)
	assert_eq(runtime.captured_count(), 0)
	assert_true(runtime.apply_rank(1))
	runtime.call(&"_on_charge_started", spec)
	runtime.call(&"_on_charge_updated", spec, 0.34, 0.17, 1.17)
	assert_eq(runtime.captured_count(), 0)
	runtime.call(&"_on_charge_released", spec, 0.34, 1.17)
	assert_false(debris.is_crucible_captured())
	assert_eq(debris_pool_layer(debris), DebrisBody2D.ACTIVE_COLLISION_LAYER)


func test_rank_caps_tuning_and_nearest_first_capture_are_deterministic() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	var far: DebrisBody2D = _spawn_debris(city, Vector2(210.0, 0.0))
	var nearest: DebrisBody2D = _spawn_debris(city, Vector2(70.0, 0.0))
	var middle: DebrisBody2D = _spawn_debris(city, Vector2(130.0, 0.0))
	assert_eq(GravityCrucibleRuntime.CAPTURE_CAPS, [0, 1, 2, 3])
	assert_eq(GravityCrucibleRuntime.CAPTURE_RADII, [0.0, 190.0, 230.0, 270.0])
	assert_eq(GravityCrucibleRuntime.THROW_SPEEDS, [0.0, 760.0, 850.0, 940.0])
	assert_eq(GravityCrucibleRuntime.IMPACT_DAMAGE, [0.0, 12.0, 16.0, 20.0])
	assert_true(runtime.apply_rank(3))
	var spec: AttackSpec = _attack(41_002)
	_start_capture(runtime, spec)
	assert_eq(runtime.captured_count(), 3)
	assert_same(runtime.captured[0], nearest)
	assert_same(runtime.captured[1], middle)
	assert_same(runtime.captured[2], far)
	for debris: DebrisBody2D in [nearest, middle, far]:
		assert_true(debris.is_crucible_captured())
		assert_eq(debris.collision_layer, 0)
		assert_eq(debris.collision_mask, 0)
		assert_true(debris.freeze)


func test_release_restores_physics_and_delivers_one_tagged_hit_per_body() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(3))
	var debris: DebrisBody2D = _spawn_debris(city, Vector2(80.0, 0.0))
	var spec: AttackSpec = _attack(
		41_003,
		DamageEvent.FLAG_KINETIC_FIELD,
		6.0
	)
	_start_capture(runtime, spec)
	assert_true(debris.is_crucible_captured())
	runtime.call(&"_on_charge_released", spec, 1.0, 1.5)
	assert_false(debris.is_crucible_captured())
	assert_false(debris.freeze)
	assert_eq(debris.collision_layer, DebrisBody2D.ACTIVE_COLLISION_LAYER)
	assert_gt(debris.linear_velocity.x, 900.0)
	assert_ne(
		int(debris.get("_crucible_effect_flags"))
		& DamageEvent.FLAG_GRAVITY_CRUCIBLE,
		0
	)
	assert_ne(
		int(debris.get("_crucible_effect_flags"))
		& DamageEvent.FLAG_KINETIC_FIELD,
		0
	)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		debris.global_position + Vector2(40.0, 0.0)
	)
	assert_not_null(target)
	target.set_physics_process(false)
	target.max_health = 1000.0
	target.current_health = 1000.0
	debris.linear_velocity = Vector2(940.0, 0.0)
	debris.call(&"_resolve_crucible_impact", target)
	assert_almost_eq(target.current_health, 974.0, 0.001)
	debris.call(&"_resolve_crucible_impact", target)
	assert_almost_eq(target.current_health, 974.0, 0.001)
	assert_eq(runtime.release_count_total, 1)


func test_cancel_pause_pool_pressure_and_reset_restore_every_body() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(2))
	var first: DebrisBody2D = _spawn_debris(city, Vector2(70.0, 0.0))
	var second: DebrisBody2D = _spawn_debris(city, Vector2(110.0, 0.0))
	var first_layer: int = first.collision_layer
	var first_mask: int = first.collision_mask
	var spec: AttackSpec = _attack(41_004)
	_start_capture(runtime, spec)
	assert_eq(runtime.captured_count(), 2)
	var held_position: Vector2 = first.global_position
	runtime.set_paused(true)
	runtime.call(&"_process", 0.25)
	assert_eq(first.global_position, held_position)
	runtime.set_paused(false)
	runtime.call(&"_process", 0.25)
	assert_ne(first.global_position, held_position)
	runtime.call(&"_on_attack_cancelled", spec)
	assert_eq(runtime.captured_count(), 0)
	for debris: DebrisBody2D in [first, second]:
		assert_false(debris.is_crucible_captured())
		assert_eq(debris.collision_layer, first_layer)
		assert_eq(debris.collision_mask, first_mask)
		assert_false(debris.freeze)
	assert_eq(city.debris_pool.active_count(), 2)
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	_start_capture(runtime, _attack(41_005))
	runtime.reset_run()
	assert_eq(runtime.current_rank, 0)
	assert_eq(runtime.captured_count(), 0)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_ordinary_wrecks_are_captured_but_boss_owned_wrecks_are_outside_registry() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(1))
	city.tank.activate(city.robot.global_position + Vector2(90.0, 0.0), city.robot)
	var fatal_event: DamageEvent = DamageEvent.new(
		41_006,
		city.robot,
		100.0,
		&"ground_smash",
		city.tank.global_position,
		Vector2.RIGHT,
		400.0
	)
	var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(
		city.tank,
		fatal_event
	)
	assert_not_null(wreck)
	var spec: AttackSpec = _attack(41_007)
	_start_capture(runtime, spec)
	assert_eq(runtime.captured_count(), 1)
	assert_same(runtime.captured[0], wreck)
	assert_true(wreck.is_crucible_captured())
	runtime.call(&"_on_charge_released", spec, 0.7, 1.35)
	assert_false(wreck.is_crucible_captured())
	assert_ne(wreck.collision_mask & EnemyWreck2D.ENEMY_LAYER, 0)
	assert_eq(city.enemy_remains_factory.active_count(), 1)


func test_captured_body_is_not_recycled_when_a_fixed_pool_is_saturated() -> void:
	var pool: DebrisPool = DebrisPool.new()
	pool.capacity = 1
	add_child_autofree(pool)
	await get_tree().process_frame
	var held: DebrisBody2D = pool.acquire(
		Transform2D(0.0, Vector2.ZERO),
		Vector2.ZERO
	)
	assert_not_null(held)
	assert_true(held.begin_crucible_capture())
	var denied: DebrisBody2D = pool.acquire(
		Transform2D(0.0, Vector2(20.0, 0.0)),
		Vector2.ZERO
	)
	assert_null(denied)
	assert_eq(pool.active_count(), 1)
	assert_true(held.is_crucible_captured())
	held.cancel_crucible_capture()
	assert_false(held.is_crucible_captured())


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.robot.global_position = Vector2(520.0, 460.0)
	city.encounter_runtime.release_all()
	city.debris_pool.release_all()
	city.enemy_remains_factory.release_all()
	return city


func _runtime(city: CitySlice) -> GravityCrucibleRuntime:
	return (
		city.upgrade_assembler.runtimes[&"GRAVITY_CRUCIBLE"]
		as GravityCrucibleRuntime
	)


func _spawn_debris(city: CitySlice, offset: Vector2) -> DebrisBody2D:
	var debris: DebrisBody2D = city.debris_pool.acquire(
		Transform2D(0.0, city.robot.global_position + offset),
		Vector2.ZERO,
		0.0,
		4.0,
		Vector2(36.0, 22.0),
		&"steel"
	)
	assert_not_null(debris)
	return debris


func _start_capture(runtime: GravityCrucibleRuntime, spec: AttackSpec) -> void:
	runtime.call(&"_on_charge_started", spec)
	runtime.call(&"_on_charge_updated", spec, 0.35, 0.175, 1.175)


func _attack(
	attack_id: int,
	effect_flags: int = DamageEvent.FLAG_NONE,
	kinetic_bonus: float = 0.0
) -> AttackSpec:
	return AttackSpec.new(
		AttackSpec.Mode.GROUND_SMASH,
		attack_id,
		1,
		0.0,
		0.12,
		0.08,
		0.26,
		100.0,
		100.0,
		1020.0,
		Vector2(192.0, 192.0),
		Vector2.ZERO,
		false,
		effect_flags,
		kinetic_bonus
	)


func debris_pool_layer(debris: DebrisBody2D) -> int:
	return debris.collision_layer

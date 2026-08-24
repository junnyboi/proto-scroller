extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const SOAK_STEPS: int = 720
const STEP_SECONDS: float = 1.0 / 60.0


func test_all_40_ranks_survive_mixed_combat_pause_and_pool_saturation() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var assembler: PlayerUpgradeAssembler = city.upgrade_assembler
	var rank_total: int = 0
	for runtime: UpgradeRuntime in assembler.runtimes.values():
		assert_true(runtime.apply_rank(runtime.max_rank()))
		rank_total += runtime.current_rank
	assert_eq(rank_total, 40)
	var machine: MachineGunRuntime = (
		assembler.runtimes[&"MACHINE_GUN"] as MachineGunRuntime
	)
	var laser: PlayerLaserWeapon = assembler.runtimes[&"LASER"] as PlayerLaserWeapon
	var flame: FlamethrowerRuntime = (
		assembler.runtimes[&"FLAMETHROWER"] as FlamethrowerRuntime
	)
	var missiles: MissileWeapon = assembler.runtimes[&"MISSILE"] as MissileWeapon
	for runtime: UpgradeRuntime in [machine, laser, flame, missiles]:
		runtime.set_process(false)
	var near_target: EnemyActor2D = _durable_target(
		city,
		&"tank",
		city.robot.global_position + Vector2(220.0, 0.0)
	)
	var missile_target: EnemyActor2D = _durable_target(
		city,
		&"soldier",
		city.robot.global_position + Vector2(300.0, 0.0)
	)
	var air_target: EnemyActor2D = _durable_target(
		city,
		&"needle",
		city.robot.global_position + Vector2(420.0, -180.0)
	)
	assert_not_null(near_target)
	assert_not_null(missile_target)
	assert_not_null(air_target)
	await get_tree().physics_frame
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	for step: int in range(SOAK_STEPS):
		machine.advance(STEP_SECONDS)
		laser.advance(STEP_SECONDS)
		flame.advance(STEP_SECONDS)
		missiles.advance(STEP_SECONDS)
		for child: Node in city.projectile_root.get_children():
			if child is Projectile2D and (child as Projectile2D).active:
				(child as Projectile2D)._physics_process(STEP_SECONDS)
		for missile: MissileProjectile2D in missiles.pool.missiles:
			if missile.active:
				missile._physics_process(STEP_SECONDS)
		if step == (SOAK_STEPS >> 1):
			_assert_pause_freezes_weapons(machine, laser, flame, missiles)
	assert_gt(machine.shots_fired, 0)
	assert_gt(laser.shots_fired, 0)
	assert_gt(flame.bursts_started, 0)
	assert_gt(flame.ticks_delivered, 0)
	assert_gt(missiles.salvos_started, 0)
	assert_gt(missiles.missiles_launched, 0)
	assert_gt(missiles.blast_count, 0)
	assert_lte(city.projectile_root.active_count(&"player_bullet"), 8)
	assert_lte(missiles.pool.active_count(), 4)
	assert_lte(laser.active_beam_count(), 2)
	assert_lte(flame.active_flame_count(), 6)
	assert_lte(flame.active_scorch_count(), 8)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())
	assert_false(InputMap.has_action(&"fire_weapon"))
	assert_false(InputMap.has_action(&"machine_gun"))
	assert_false(InputMap.has_action(&"missile"))
	assert_false(InputMap.has_action(&"laser"))
	assert_false(InputMap.has_action(&"flamethrower"))


func _assert_pause_freezes_weapons(
	machine: MachineGunRuntime,
	laser: PlayerLaserWeapon,
	flame: FlamethrowerRuntime,
	missiles: MissileWeapon
) -> void:
	var counters: PackedInt32Array = PackedInt32Array([
		machine.shots_fired,
		laser.shots_fired,
		flame.ticks_delivered,
		missiles.missiles_launched,
	])
	for runtime: UpgradeRuntime in [machine, laser, flame, missiles]:
		runtime.set_paused(true)
	machine.advance(1.0)
	laser.advance(1.0)
	flame.advance(1.0)
	missiles.advance(1.0)
	assert_eq(machine.shots_fired, counters[0])
	assert_eq(laser.shots_fired, counters[1])
	assert_eq(flame.ticks_delivered, counters[2])
	assert_eq(missiles.missiles_launched, counters[3])
	assert_false(flame.loop_audio_active)
	for runtime: UpgradeRuntime in [machine, laser, flame, missiles]:
		runtime.set_paused(false)


func _spawn_isolated_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _durable_target(
	city: CitySlice,
	kind: StringName,
	position: Vector2
) -> EnemyActor2D:
	var enemy: EnemyActor2D = city.encounter_runtime.acquire(kind, position)
	if enemy != null:
		enemy.set_physics_process(false)
		enemy.max_health = 1000000.0
		enemy.current_health = enemy.max_health
	return enemy

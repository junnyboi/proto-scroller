extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_laser_penetrates_three_sorted_receivers_and_uses_no_projectiles() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var laser: PlayerLaserWeapon = _laser(city)
	laser.set_process(false)
	laser.apply_rank(1)
	var beam_y: float = laser.emitter.global_position.y
	var enemies: Array[EnemyActor2D] = []
	for index: int in range(4):
		var enemy: EnemyActor2D = city.encounter_runtime.acquire(
			&"soldier",
			Vector2(920.0 + 100.0 * float(index), beam_y)
		)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await get_tree().physics_frame
	var projectile_count: int = city.projectile_root.active_count()
	laser.call(&"_fire", Vector2.RIGHT)
	assert_eq(laser.last_accepted_count, 3)
	assert_eq(enemies[0].current_health, enemies[0].max_health - 18.0)
	assert_eq(enemies[1].current_health, enemies[1].max_health - 18.0)
	assert_eq(enemies[2].current_health, enemies[2].max_health - 18.0)
	assert_eq(enemies[3].current_health, enemies[3].max_health)
	assert_eq(laser.active_beam_count(), 1)
	assert_eq(city.projectile_root.active_count(), projectile_count)


func test_laser_rank_tuning_and_structural_damage_are_exact() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var laser: PlayerLaserWeapon = _laser(city)
	laser.set_process(false)
	laser.apply_rank(5)
	assert_eq(laser.ACTOR_DAMAGE[laser.current_rank], 26.0)
	assert_eq(laser.STRUCTURAL_DAMAGE[laser.current_rank], 18.0)
	assert_eq(laser.COOLDOWNS[laser.current_rank], 0.95)
	assert_eq(laser.TARGET_COUNTS[laser.current_rank], 5)
	var cell: Destructible2D = city.building.get_cell(0, 1)
	var health_before: float = cell.current_health
	var direction: Vector2 = laser.emitter.global_position.direction_to(cell.global_position)
	await get_tree().physics_frame
	laser.call(&"_fire", direction)
	assert_almost_eq(cell.current_health, health_before - 18.0, 0.001)


func test_laser_reuses_two_visual_slots_and_honors_pause() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var laser: PlayerLaserWeapon = _laser(city)
	laser.set_process(false)
	laser.apply_rank(3)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		Vector2(1050.0, laser.emitter.global_position.y)
	)
	target.set_physics_process(false)
	await get_tree().physics_frame
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	for shot_index: int in range(3):
		laser.call(&"_fire", Vector2.RIGHT)
	assert_eq(laser.shots_fired, 3)
	assert_eq(laser.active_beam_count(), 2)
	assert_eq(laser.beams.size(), 2)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	assert_eq(city.projectile_root.active_count(&"player_bullet"), 0)
	laser.cooldown_remaining = 0.0
	laser.set_paused(true)
	laser.advance(2.0)
	assert_eq(laser.shots_fired, 3)
	assert_false(InputMap.has_action(&"laser"))
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func _spawn_isolated_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _laser(city: CitySlice) -> PlayerLaserWeapon:
	return city.upgrade_assembler.runtimes[&"LASER"] as PlayerLaserWeapon

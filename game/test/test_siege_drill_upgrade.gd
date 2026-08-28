extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_siege_drill_only_deploys_for_successful_ranked_dashes() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: SiegeDrillRuntime = _runtime(city)
	assert_not_null(runtime)
	assert_eq(runtime.current_rank, 0)
	assert_true(city.robot._start_dodge(1))
	assert_false(runtime.hitbox.active)
	city.robot.cancel_dodge()
	city.robot.dodge_cooldown_remaining = 0.0
	assert_true(runtime.apply_rank(1))
	assert_true(city.robot._start_dodge(1))
	assert_true(runtime.hitbox.active)
	assert_eq(runtime.deployment_count, 1)
	var drill_attack_id: int = runtime.hitbox.attack_id
	assert_gt(drill_attack_id, 0)
	assert_false(city.robot._start_dodge(1))
	assert_eq(runtime.deployment_count, 1)
	assert_eq(runtime.hitbox.attack_id, drill_attack_id)
	city.robot.cancel_dodge()
	assert_false(runtime.hitbox.active)


func test_ranks_change_payload_without_changing_dodge_contract() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: SiegeDrillRuntime = _runtime(city)
	var robot: GiantRobotController = city.robot
	var baseline: PackedFloat32Array = PackedFloat32Array([
		robot.dodge_speed,
		robot.dodge_duration,
		robot.dodge_cooldown_seconds,
		robot.dodge_invulnerability_seconds,
	])
	for rank: int in range(1, 4):
		assert_true(runtime.apply_rank(rank))
		assert_almost_eq(robot.dodge_speed, baseline[0], 0.001)
		assert_almost_eq(robot.dodge_duration, baseline[1], 0.001)
		assert_almost_eq(robot.dodge_cooldown_seconds, baseline[2], 0.001)
		assert_almost_eq(robot.dodge_invulnerability_seconds, baseline[3], 0.001)
		assert_eq(SiegeDrillHitbox.ACTOR_DAMAGE[rank], [40.0, 48.0, 56.0][rank - 1])
		assert_eq(
			SiegeDrillHitbox.STRUCTURAL_DAMAGE[rank],
			[36.0, 44.0, 52.0][rank - 1]
		)
		assert_eq(
			SiegeDrillHitbox.IMPULSE_PER_MASS[rank],
			[360.0, 420.0, 480.0][rank - 1]
		)


func test_drill_hits_forward_enemy_once_per_dash_and_ignores_rear_enemy() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: SiegeDrillRuntime = _runtime(city)
	assert_true(runtime.apply_rank(2))
	city.robot.global_position = Vector2(520.0, 460.0)
	city.robot.facing = 1
	var forward: EnemyActor2D = _durable_enemy(
		city,
		&"tank",
		city.robot.global_position + Vector2(108.0, 8.0)
	)
	var rear: EnemyActor2D = _durable_enemy(
		city,
		&"soldier",
		city.robot.global_position + Vector2(-108.0, 8.0)
	)
	await get_tree().physics_frame
	var forward_health: float = forward.current_health
	var rear_health: float = rear.current_health
	assert_true(city.robot._start_dodge(1))
	runtime.hitbox.advance()
	runtime.hitbox.advance()
	assert_almost_eq(forward.current_health, forward_health - 48.0, 0.001)
	assert_eq(rear.current_health, rear_health)
	assert_eq(runtime.hitbox.accepted_hit_count, 1)
	assert_eq(runtime.hitbox.hit_target_count(), 1)
	city.robot.cancel_dodge()


func test_dash_cancel_retracts_before_jab_cross_and_cleanup_is_fixed() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: SiegeDrillRuntime = _runtime(city)
	assert_true(runtime.apply_rank(3))
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	assert_true(city.robot._start_dodge(1))
	assert_true(runtime.hitbox.active)
	var attack_id: int = city.contextual_attacks.begin_charge()
	assert_gt(attack_id, 0)
	assert_false(runtime.hitbox.active)
	assert_true(city.contextual_attacks.is_charging())
	city.contextual_attacks.cancel_attack()
	runtime.set_paused(true)
	city.robot.dodge_cooldown_remaining = 0.0
	assert_true(city.robot._start_dodge(1))
	assert_false(runtime.hitbox.active)
	runtime.set_paused(false)
	runtime.stop_and_release()
	assert_false(runtime.hitbox.active)
	runtime.reset_run()
	assert_eq(runtime.current_rank, 0)
	assert_false(runtime.hitbox.active)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.encounter_runtime.release_all()
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _runtime(city: CitySlice) -> SiegeDrillRuntime:
	return city.upgrade_assembler.runtimes[&"SIEGE_DRILL"] as SiegeDrillRuntime


func _durable_enemy(
	city: CitySlice,
	kind: StringName,
	position: Vector2
) -> EnemyActor2D:
	var enemy: EnemyActor2D = city.encounter_runtime.acquire(kind, position)
	assert_not_null(enemy)
	if enemy != null:
		enemy.set_physics_process(false)
		enemy.max_health = 1000.0
		enemy.current_health = enemy.max_health
	return enemy

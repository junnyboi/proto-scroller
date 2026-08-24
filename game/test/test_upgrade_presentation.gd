extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_destruction_adds_one_visual_counterpart_per_baseline_unit_only() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var runtime: DestructionUpgradeRuntime = (
		city.upgrade_assembler.runtimes[&"DESTRUCTION"] as DestructionUpgradeRuntime
	)
	assert_false(runtime.field.is_processing())
	assert_true(runtime.apply_rank(1))
	var physical_before: int = city.debris_pool.active_count()
	var event: GameplayEvent = _debris_event(1, 4, &"concrete")
	assert_true(city.rampage_session.publish(event))
	assert_eq(runtime.field.active_count(), 4)
	assert_true(runtime.field.is_processing())
	assert_eq(runtime.visual_spawn_count, 4)
	assert_eq(city.debris_pool.active_count(), physical_before)
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	runtime.call(&"_on_event_published", event)
	assert_eq(runtime.field.active_count(), 4)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	runtime.set_paused(true)
	assert_false(runtime.field.is_processing())
	runtime.set_paused(false)
	assert_true(runtime.field.is_processing())
	runtime.field.call(&"_process", 2.0)
	assert_eq(runtime.field.active_count(), 0)
	assert_false(runtime.field.is_processing())
	runtime.field.reset_field()
	assert_false(runtime.field.is_processing())


func test_cosmetic_debris_saturates_at_64_and_recycles_without_growth() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var runtime: DestructionUpgradeRuntime = (
		city.upgrade_assembler.runtimes[&"DESTRUCTION"] as DestructionUpgradeRuntime
	)
	runtime.apply_rank(1)
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	for index: int in range(80):
		assert_true(city.rampage_session.publish(
			_debris_event(1000 + index, 1, &"glass" if index < 40 else &"steel")
		))
	assert_eq(runtime.field.active_count(), 64)
	assert_eq(runtime.visual_spawn_count, 80)
	assert_eq(runtime.field.recycle_count, 16)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	assert_eq(city.debris_pool.active_count(), 0)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_shockwave_is_one_zero_reward_cue_per_ground_smash() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var runtime: ShockwaveUpgradeRuntime = (
		city.upgrade_assembler.runtimes[&"SHOCKWAVE"] as ShockwaveUpgradeRuntime
	)
	assert_true(runtime.apply_rank(1))
	var published: Array[GameplayEvent] = []
	city.rampage_session.event_hub.event_published.connect(
		func(event: GameplayEvent) -> void:
			if event.kind == GameplayEvent.Kind.GROUND_SMASH_SHOCKWAVE:
				published.append(event)
	)
	var score_before: int = city.rampage_session.current_score()
	var experience_before: int = city.rampage_session.run_experience.total_experience
	var smash: AttackSpec = _attack(AttackSpec.Mode.GROUND_SMASH, 700)
	runtime.call(&"_on_attack_active", smash)
	assert_eq(runtime.active_count(), 1)
	assert_eq(runtime.rings[0].lifetime, 1.0)
	var visual_ground: Node2D = city.robot.get_node(
		^"VisualRoot/VisualGroundOrigin"
	) as Node2D
	assert_eq(runtime.rings[0].global_position, visual_ground.global_position)
	assert_eq(published.size(), 1)
	assert_eq(published[0].dedupe_key, &"shockwave:700")
	assert_eq(published[0].root_attack_id, 700)
	assert_eq(published[0].base_points, 0)
	assert_eq(published[0].world_position, visual_ground.global_position)
	assert_eq(city.rampage_session.current_score(), score_before)
	assert_eq(city.rampage_session.run_experience.total_experience, experience_before)
	assert_gt(city.camera_rig.impact_velocity.length(), 0.0)
	runtime.call(&"_on_attack_active", smash)
	assert_eq(runtime.active_count(), 1)
	assert_eq(published.size(), 1)
	runtime.call(&"_on_attack_active", _attack(AttackSpec.Mode.JAB_CROSS, 701))
	assert_eq(runtime.active_count(), 1)
	assert_eq(published.size(), 1)
	assert_true(runtime.apply_rank(3))
	runtime.call(&"_on_attack_active", _attack(AttackSpec.Mode.GROUND_SMASH, 702))
	assert_eq(runtime.active_count(), 2)
	assert_eq(runtime.rings[1].lifetime, 3.0)


func test_shockwave_strictly_denies_eleventh_ring_without_node_growth() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var runtime: ShockwaveUpgradeRuntime = (
		city.upgrade_assembler.runtimes[&"SHOCKWAVE"] as ShockwaveUpgradeRuntime
	)
	runtime.apply_rank(3)
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	for index: int in range(11):
		runtime.call(
			&"_on_attack_active",
			_attack(AttackSpec.Mode.GROUND_SMASH, 800 + index)
		)
	assert_eq(runtime.active_count(), 10)
	assert_eq(runtime.spawn_count, 10)
	assert_eq(runtime.denial_count, 1)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	var first_age: float = runtime.rings[0].age
	runtime.set_paused(true)
	runtime.rings[0].call(&"_process", 0.5)
	assert_eq(runtime.rings[0].age, first_age)


func _debris_event(key_id: int, units: int, material: StringName) -> GameplayEvent:
	var event: GameplayEvent = GameplayEvent.new(
		StringName("presentation:%d" % key_id),
		key_id,
		GameplayEvent.Kind.CELL_DESTROYED,
		GameplayEvent.CELL_BREACH,
		0,
		0.0,
		false,
		Vector2(500.0, 500.0),
		material
	)
	event.debris_units = units
	event.presentation_direction = Vector2(1.0, -0.2).normalized()
	event.presentation_speed = 600.0
	return event


func _attack(mode: AttackSpec.Mode, attack_id: int) -> AttackSpec:
	return AttackSpec.new(
		mode,
		attack_id,
		1,
		0.0,
		0.1,
		0.01,
		0.2,
		180.0,
		180.0,
		1020.0,
		Vector2(640.0, 640.0),
		Vector2.ZERO
	)

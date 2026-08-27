extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func _hollow_progress(pattern: BuildingDamagePattern2D) -> float:
	return float(pattern.cavity_material().get_shader_parameter("hollow_progress"))


func _hollow_extents(pattern: BuildingDamagePattern2D) -> Vector2:
	return pattern.cavity_material().get_shader_parameter("hollow_extents_uv") as Vector2


func test_six_chunks_own_fixed_deterministic_destructible_slots() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: StreamedDestructibleRuntime = city.streamed_destructibles
	assert_eq(runtime.active_building_count(), RuntimeBudget.STREAMED_BUILDINGS)
	assert_eq(runtime.active_prop_count(), RuntimeBudget.STREAMED_PROPS)
	assert_eq(runtime.post_warm_creation_count, 0)
	var first: CityChunkBlueprint = CityChunkBlueprint.generate(731, 9)
	var replay: CityChunkBlueprint = CityChunkBlueprint.generate(731, 9)
	var changed: CityChunkBlueprint = CityChunkBlueprint.generate(732, 9)
	assert_eq(first.building_x, replay.building_x)
	assert_eq(first.car_x, replay.car_x)
	assert_eq(first.lamp_x, replay.lamp_x)
	assert_ne(first.generation_seed, changed.generation_seed)
	_record_test_execution()


func test_destroyed_building_and_prop_restore_after_slot_reuse() -> void:
	var city: CitySlice = await _spawn_city()
	var original_building_slot: int = city.building.get_instance_id()
	var cell: Destructible2D = city.building.get_cell(0, 1)
	var partial_cell: Destructible2D = city.building.get_cell(1, 1)
	cell.receive_damage(_fatal_event(city, cell, 31_001))
	partial_cell.receive_damage(_fatal_event(city, partial_cell, 31_003, 60.0))
	var partial_health: float = partial_cell.current_health
	var partial_pattern: BuildingDamagePattern2D = partial_cell.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	var pattern_signature: String = partial_pattern.pattern_signature()
	var detail_mask: int = partial_pattern.damage_detail_mask()
	assert_gt(partial_pattern.damage_detail_count(), 0)
	city.car.current_health = 1.0
	city.car.receive_damage(_fatal_event(city, city.car, 31_002))
	assert_true(cell.is_destroyed())
	assert_true(city.car.is_broken)
	await _move_to_logical_chunk(city, 9)
	assert_true(city.streamed_destructibles.ledger.has_state(&"chunk:0:building"))
	assert_true(city.streamed_destructibles.ledger.has_state(&"chunk:0:car"))
	await _move_to_logical_chunk(city, 0)
	assert_eq(String(city.building.get_meta(&"stream_object_id")), "chunk:0:building")
	assert_true(city.building.is_cell_destroyed(0, 1))
	assert_true(city.building.ground_passage_open())
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			assert_true(_cell_collision(city.building, column, row).disabled)
	var restored_partial: Destructible2D = city.building.get_cell(1, 1)
	assert_almost_eq(restored_partial.current_health, partial_health, 0.01)
	var restored_pattern: BuildingDamagePattern2D = restored_partial.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	assert_eq(restored_pattern.pattern_signature(), pattern_signature)
	assert_eq(restored_pattern.damage_detail_mask(), detail_mask)
	assert_gt(restored_pattern.damage_detail_count(), 0)
	assert_eq(restored_pattern.active_damage_effect_count(), 0)
	assert_true(city.car.is_broken)
	assert_ne(city.building.get_instance_id(), 0)
	assert_eq(city.streamed_destructibles.post_warm_creation_count, 0)
	assert_true(
		city.building.get_instance_id() == original_building_slot
		or city.streamed_destructibles.active_building_count() == 6
	)
	_record_test_execution()


func test_one_ground_breach_opens_passage_to_the_next_live_facade() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	city.robot.set_physics_process(false)
	city.robot.gravity = 0.0
	city.robot.velocity = Vector2.ZERO
	var first_variant: StringName = city.building.current_variant_id()
	var breached_cell: Destructible2D = city.building.get_cell(0, 1)
	assert_true(breached_cell.receive_damage(_fatal_event(city, breached_cell, 31_050)))
	await get_tree().physics_frame
	assert_true(city.building.ground_passage_open())
	assert_eq(city.world_stream.district_clear_count(), 1)
	assert_almost_eq(
		city.world_stream.district_exit_barrier.position.x,
		2.0 * CityWorldStream.CHUNK_WIDTH,
		0.01
	)
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			assert_true(_cell_collision(city.building, column, row).disabled)
	for _frame: int in range(420):
		city.robot.physics_step(1.0, 1.0 / 60.0)
		city.world_stream.advance_stream()
		await get_tree().physics_frame
	assert_eq(city.world_stream.current_logical_chunk, 1)
	assert_ne(city.building.current_variant_id(), first_variant)
	assert_eq(
		city.building.current_variant_id(),
		CityDistrictCatalog.variant_for_chunk(city.world_stream.run_seed, 1).variant_id
	)
	_record_test_execution()


func test_destroyed_cell_disables_hurtbox_and_reset_restores_it() -> void:
	var city: CitySlice = await _spawn_city()
	var building: StructuralBuilding2D = city.building
	var cell: Destructible2D = building.get_cell(0, 1)
	var hurtbox_collision: CollisionShape2D = cell.get_node(
		^"Hurtbox/CollisionShape2D"
	) as CollisionShape2D
	assert_false(hurtbox_collision.disabled)
	assert_true(cell.receive_damage(_fatal_event(city, cell, 31_075)))
	await get_tree().physics_frame
	assert_true(cell.is_destroyed())
	assert_true(hurtbox_collision.disabled)
	building.restore_stream_state({})
	await get_tree().physics_frame
	assert_false(cell.is_destroyed())
	assert_false(hurtbox_collision.disabled)
	_record_test_execution()


func test_destroyed_segment_keeps_alpha_safe_procedural_hollow_and_details() -> void:
	var city: CitySlice = await _spawn_city()
	var cell: Destructible2D = city.building.get_cell(1, 1)
	var upper_cell: Destructible2D = city.building.get_cell(1, 0)
	var upper_pattern: BuildingDamagePattern2D = upper_cell.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	var pattern: BuildingDamagePattern2D = cell.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	assert_true(cell.receive_damage(_fatal_event(city, cell, 31_101, 60.0)))
	assert_true(pattern.visible)
	assert_gt(pattern.contour().size(), 0)
	assert_gt(pattern.crack_count(), 0)
	assert_false(pattern.is_destroyed_stage())
	assert_gt(_hollow_progress(pattern), 0.0)
	var damaged_extents: Vector2 = _hollow_extents(pattern)
	var cable: BuildingDamageAttachment2D = pattern.get_node(
		^"DanglingCables"
	) as BuildingDamageAttachment2D
	var pipe: BuildingDamageAttachment2D = pattern.get_node(
		^"BrokenWaterPipe"
	) as BuildingDamageAttachment2D
	assert_eq(cable.particles.name, "CableSparks")
	assert_eq(pipe.particles.name, "WaterSpray")
	assert_eq(pipe.display_size(), Vector2(31.5, 57.0))
	assert_lte(
		cable.particles.amount,
		BuildingDamageAttachment2D.MAX_SPARK_PARTICLES
	)
	assert_lte(
		pipe.particles.amount,
		BuildingDamageAttachment2D.MAX_WATER_PARTICLES
	)
	var initial_rotation: float = cable.rotation
	for _step: int in range(8):
		cable._process(0.1)
	assert_ne(cable.rotation, initial_rotation)
	assert_ne(pattern.cable_sway_offset(), 0.0)
	assert_lte(absf(pattern.cable_sway_offset()), 0.26)
	assert_true(cell.receive_damage(_fatal_event(city, cell, 31_102)))
	assert_true(cell.is_destroyed())
	assert_true(pattern.visible)
	assert_true(pattern.is_destroyed_stage())
	assert_almost_eq(_hollow_progress(pattern), 1.0, 0.0001)
	assert_gt(_hollow_extents(pattern).x, damaged_extents.x)
	assert_gt(_hollow_extents(pattern).y, damaged_extents.y)
	assert_eq(pattern.contour().size(), BuildingDamagePattern2D.CONTOUR_POINTS)
	assert_gt(pattern.crack_count(), 0)
	assert_eq(pattern.damage_detail_count(), 2)
	assert_true(cable.is_processing())
	assert_almost_eq(
		pattern.cavity_darken_strength(),
		BuildingDamagePattern2D.DESTROYED_DARKEN_STRENGTH,
		0.0001
	)
	assert_false(upper_cell.is_destroyed())
	assert_almost_eq(
		upper_cell.current_health,
		upper_cell.max_health * 0.5,
		0.01
	)
	assert_true(upper_pattern.visible)
	assert_gt(upper_pattern.crack_count(), 0)
	var intact_sprite: Sprite2D = cell.get_node(^"IntactVisual") as Sprite2D
	assert_true(intact_sprite.visible)
	assert_eq(intact_sprite.material, pattern.cavity_material())
	assert_true((cell.get_node(^"RubbleVisual") as Sprite2D).visible)
	assert_null(cell.get_node_or_null(^"RubbleEdgeVisual"))
	var cavity_material: ShaderMaterial = pattern.cavity_material()
	assert_not_null(cavity_material)
	assert_not_null(cavity_material.shader)
	assert_true(cavity_material.shader.code.contains("discard"))
	assert_true(cavity_material.shader.code.contains("facade.a <= alpha_threshold"))
	assert_true(cavity_material.shader.code.contains("radial < boundary - edge_softness"))
	assert_eq(
		float(cavity_material.get_shader_parameter("alpha_threshold")),
		BuildingDamagePattern2D.FACADE_ALPHA_THRESHOLD
	)
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/destruction/building_damage_pattern_2d.gd"
	)
	assert_false(source.contains("draw_colored_polygon(_contour"))
	var captured: Dictionary = cell.capture_stream_state()
	var signature: String = pattern.pattern_signature()
	cell.restore_stream_state(captured)
	assert_eq(pattern.pattern_signature(), signature)
	assert_true(pattern.is_destroyed_stage())
	assert_eq(pattern.damage_detail_count(), 2)
	cell.restore_stream_state({"destroyed": true, "health": 0.0})
	assert_true(cell.is_destroyed())
	assert_true(pattern.visible)
	assert_gt(pattern.pattern_signature().length(), 0)
	assert_eq(pattern.damage_detail_count(), 2)
	_record_test_execution()


func test_damage_progressively_hollows_the_authored_facade_into_jagged_side_and_top_rims() -> void:
	var city: CitySlice = await _spawn_city()
	var cell: Destructible2D = city.building.get_cell(1, 0)
	var pattern: BuildingDamagePattern2D = cell.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	var sprite: Sprite2D = cell.get_node(^"IntactVisual") as Sprite2D
	assert_eq(sprite.material, pattern.cavity_material())
	assert_almost_eq(_hollow_progress(pattern), 0.0, 0.0001)
	assert_eq(_hollow_extents(pattern), Vector2.ZERO)
	assert_almost_eq(pattern.cavity_darken_strength(), 0.0, 0.0001)
	var progress_samples: Array[float] = [0.20, 0.55, 0.80]
	var prior_progress: float = 0.0
	var prior_extents: Vector2 = Vector2.ZERO
	var prior_darkening: float = 0.0
	var attack_id: int = 31_200
	for target_progress: float in progress_samples:
		var next_health: float = cell.max_health * (1.0 - target_progress)
		var damage: float = cell.current_health - next_health
		assert_true(cell.receive_damage(_fatal_event(city, cell, attack_id, damage)))
		attack_id += 1
		assert_almost_eq(_hollow_progress(pattern), target_progress, 0.0001)
		assert_gt(_hollow_progress(pattern), prior_progress)
		assert_gt(_hollow_extents(pattern).x, prior_extents.x)
		assert_gt(_hollow_extents(pattern).y, prior_extents.y)
		assert_gt(pattern.cavity_darken_strength(), prior_darkening)
		prior_progress = _hollow_progress(pattern)
		prior_extents = _hollow_extents(pattern)
		prior_darkening = pattern.cavity_darken_strength()
	var progressive_state: Dictionary = cell.capture_stream_state()
	var progressive_signature: String = pattern.pattern_signature()
	cell.restore_stream_state(progressive_state)
	assert_almost_eq(_hollow_progress(pattern), 0.80, 0.0001)
	assert_eq(_hollow_extents(pattern), prior_extents)
	assert_eq(pattern.pattern_signature(), progressive_signature)
	assert_eq(sprite.material, pattern.cavity_material())
	assert_true(cell.receive_damage(_fatal_event(city, cell, attack_id, cell.current_health)))
	assert_true(cell.is_destroyed())
	assert_almost_eq(_hollow_progress(pattern), 1.0, 0.0001)
	assert_almost_eq(
		pattern.cavity_darken_strength(),
		BuildingDamagePattern2D.DESTROYED_DARKEN_STRENGTH,
		0.0001
	)
	var terminal_extents: Vector2 = _hollow_extents(pattern)
	assert_gte(terminal_extents.x, 0.35)
	assert_gte(terminal_extents.y, 0.38)
	assert_gt(0.5 - terminal_extents.x, 0.09)
	assert_gt(BuildingDamagePattern2D.HOLLOW_CENTER_Y - terminal_extents.y, 0.09)
	assert_gte(BuildingDamagePattern2D.HOLLOW_CENTER_Y + terminal_extents.y, 0.94)
	assert_eq(pattern.damage_detail_count(), 2)
	assert_gte(pattern.crack_count(), BuildingDamagePattern2D.BASE_CRACK_COUNT + 3)
	var shader_code: String = pattern.cavity_material().shader.code
	assert_true(shader_code.contains("texture(TEXTURE, UV)"))
	assert_true(shader_code.contains("notches"))
	assert_true(shader_code.contains("lower_breach"))
	assert_true(shader_code.contains("discard"))
	_record_test_execution()


func test_run_reset_clears_sparse_mutations_without_reallocating() -> void:
	var city: CitySlice = await _spawn_city()
	var building_ids: PackedInt64Array = PackedInt64Array()
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		building_ids.append(building.get_instance_id())
	var cell: Destructible2D = city.building.get_cell(0, 1)
	cell.receive_damage(_fatal_event(city, cell, 32_001))
	await _move_to_logical_chunk(city, 9)
	assert_gt(city.streamed_destructibles.mutation_count(), 0)
	city.robot.global_position.x = 700.0
	city.world_stream.reset_stream(917)
	await get_tree().process_frame
	assert_eq(city.streamed_destructibles.mutation_count(), 0)
	assert_false(city.building.is_cell_destroyed(0, 1))
	assert_eq(city.streamed_destructibles.active_building_count(), 6)
	for index: int in range(building_ids.size()):
		assert_eq(
			city.streamed_destructibles.buildings[index].get_instance_id(),
			building_ids[index]
		)
	_record_test_execution()


func test_district_readiness_scales_enemy_and_hazard_pressure_inside_caps() -> void:
	var city: CitySlice = await _spawn_city()
	await _move_to_logical_chunk(city, 15)
	assert_eq(city.world_stream.progression_tier(), 3)
	assert_eq(city.world_stream.current_district_id, &"MILITARY")
	var director: DistrictResponseDirector = city.urban_siege.director
	director.stop()
	city.encounter_runtime.release_all()
	var act: DistrictAct = city.urban_siege.district.acts[3]
	var beat: DistrictBeat = act.beats[0]
	var business: DistrictPressureProfile = DistrictPressureCatalog.profile_by_index(0)
	var military: DistrictPressureProfile = DistrictPressureCatalog.profile_by_index(3)
	var base_copies: Dictionary[int, int] = director._progression_copy_plan(
		beat,
		business
	)
	var scaled_copies: Dictionary[int, int] = director._progression_copy_plan(
		beat,
		military
	)
	assert_eq(base_copies.size(), 0)
	assert_gt(scaled_copies.size(), 0)
	assert_lte(
		director._planned_threat(beat, scaled_copies),
		EnemySpawnTuning.scaled_threat(military.live_threat_ceiling)
	)
	var base_elites: Dictionary[int, StringName] = director._roll_elite_plan(act, beat, 0)
	var scaled_elites: Dictionary[int, StringName] = director._roll_elite_plan(act, beat, 3)
	assert_gte(scaled_elites.size(), base_elites.size())
	var controller: HazardPressureController = city.urban_siege.hazard_pressure
	controller.configure(4401, 1)
	var base_hazards: Array[Dictionary] = controller.plan_for_beat(
		3,
		0,
		act,
		beat,
		city.robot.global_position.x,
		business
	)
	var base_budget: int = controller.last_used_budget
	controller.configure(4401, 1)
	var scaled_hazards: Array[Dictionary] = controller.plan_for_beat(
		3,
		0,
		act,
		beat,
		city.robot.global_position.x,
		military
	)
	assert_gte(scaled_hazards.size(), base_hazards.size())
	assert_gte(controller.last_used_budget, base_budget)
	assert_lte(controller.last_used_budget, RuntimeBudget.HAZARD_PRESSURE)
	assert_lte(scaled_hazards.size(), RuntimeBudget.PENDING_HAZARDS)
	city.encounter_runtime.release_all()
	director.ledger.cancel_all()
	director.phase_index = 3
	director.beat_index = -1
	director.state = director.STATE_WAITING
	city.rampage_session.run_experience.level = military.readiness_level
	director._try_start_next_beat()
	var authored_count: int = 0
	for entry: EnemySpawnEntry in beat.spawns:
		authored_count += EnemyArchetypeCatalog.spawn_multiplier(StringName(entry.kind))
	assert_eq(
		director._beat_pending.size(),
		EnemySpawnTuning.scaled_count(authored_count + scaled_copies.size())
	)
	assert_eq(director.progression_peak_tier, 3)
	assert_lte(
		director.progression_peak_threat,
		EnemySpawnTuning.scaled_threat(military.live_threat_ceiling)
	)
	assert_lte(director._hazard_pending.size(), RuntimeBudget.PENDING_HAZARDS)
	_record_test_execution()


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	return city


func _move_to_logical_chunk(city: CitySlice, logical_index: int) -> void:
	_unlock_districts_through(city.world_stream, logical_index)
	city.robot.global_position.x = city.world_stream.runtime_x_for_logical_index(logical_index) + 700.0
	city.world_stream.advance_stream()
	await get_tree().physics_frame
	city.world_stream.advance_stream()
	await get_tree().process_frame


func _unlock_districts_through(stream: CityWorldStream, logical_index: int) -> void:
	var target_district_index: int = CityDistrictCatalog.district_index_for_chunk(
		logical_index
	)
	while stream.unlocked_district_index < target_district_index:
		var district: CityDistrictProfile = CityDistrictCatalog.districts()[
			stream.unlocked_district_index
		]
		stream.current_district_id = district.district_id
		for variant: StructuralBuildingVariant in district.building_variants:
			var building_value: StructuralBuilding2D = StructuralBuilding2D.new()
			building_value.set_meta(&"district_id", district.district_id)
			building_value.set_meta(&"district_index", district.district_index)
			building_value.set_meta(&"building_variant_id", variant.variant_id)
			stream.report_building_cleared(building_value)
			building_value.free()


func _fatal_event(
	city: CitySlice,
	target: Node2D,
	attack_id: int,
	damage: float = 10_000.0
) -> DamageEvent:
	var event: DamageEvent = DamageEvent.new(
		attack_id,
		city.robot,
		damage,
		&"jab_cross"
	)
	event.hit_position = target.global_position
	event.direction = Vector2.RIGHT
	event.impulse_per_mass = 900.0
	return event


func _cell_collision(
	building: StructuralBuilding2D,
	column: int,
	row: int
) -> CollisionShape2D:
	return building.get_cell(column, row).get_node(
		^"IntactBody/CollisionShape2D"
	) as CollisionShape2D


func _record_test_execution() -> void:
	if OS.has_environment("MGS_TEST_LOG"):
		var file: FileAccess = FileAccess.open(
			OS.get_environment("MGS_TEST_LOG"),
			FileAccess.WRITE_READ
		)
		if file != null:
			file.seek_end()
			file.store_line("test_endless_destructible_city")

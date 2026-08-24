extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


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


func test_destroyed_segment_culls_details_and_hollows_full_facade() -> void:
	var city: CitySlice = await _spawn_city()
	var cell: Destructible2D = city.building.get_cell(1, 1)
	var upper_cell: Destructible2D = city.building.get_cell(1, 0)
	var upper_pattern: BuildingDamagePattern2D = upper_cell.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	var pattern: BuildingDamagePattern2D = cell.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	var edge: BuildingRubbleEdge2D = cell.get_node(
		^"RubbleEdgeVisual"
	) as BuildingRubbleEdge2D
	assert_true(cell.receive_damage(_fatal_event(city, cell, 31_101, 60.0)))
	assert_eq(pattern.damage_detail_count(), 2)
	assert_eq(pattern.damage_effect_activation_count(), 2)
	assert_eq(pattern.active_damage_effect_count(), 2)
	assert_true(pattern.visible)
	var cable: BuildingDamageAttachment2D = pattern.get_node(
		^"DanglingCables"
	) as BuildingDamageAttachment2D
	var pipe: BuildingDamageAttachment2D = pattern.get_node(
		^"BrokenWaterPipe"
	) as BuildingDamageAttachment2D
	assert_true(cable.is_processing())
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
	assert_false(pattern.visible)
	assert_eq(pattern.damage_detail_count(), 0)
	assert_eq(pattern.active_damage_effect_count(), 0)
	assert_false(cable.is_processing())
	assert_false(upper_cell.is_destroyed())
	assert_almost_eq(
		upper_cell.current_health,
		upper_cell.max_health * 0.5,
		0.01
	)
	assert_true(upper_pattern.visible)
	assert_gt(upper_pattern.crack_count(), 0)
	assert_eq(edge.exposed_edge_count(), 3)
	assert_eq(edge.active_shell_count(), 1)
	assert_false(edge.is_edge_exposed(BuildingRubbleEdge2D.Edge.BOTTOM))
	assert_true(edge.visible)
	var intact_sprite: Sprite2D = cell.get_node(^"IntactVisual") as Sprite2D
	var hollow_facade: Sprite2D = edge.facade_sprite()
	assert_not_null(hollow_facade)
	assert_eq(edge.source_texture(), intact_sprite.texture)
	assert_eq(edge.source_region(), intact_sprite.region_rect)
	assert_eq(hollow_facade.texture, intact_sprite.texture)
	assert_eq(hollow_facade.region_rect, intact_sprite.region_rect)
	assert_true(hollow_facade.region_enabled)
	var cell_size: Vector2 = city.building.display_size / Vector2(
		StructuralBuilding2D.COLUMNS,
		StructuralBuilding2D.ROWS
	)
	assert_eq(hollow_facade.region_rect.size * hollow_facade.scale, cell_size)
	assert_eq(
		edge.cutout_parameter(&"hole_half_extents"),
		BuildingRubbleEdge2D.HOLE_HALF_EXTENTS
	)
	assert_almost_eq(BuildingRubbleEdge2D.HOLE_HALF_EXTENTS.x, 0.34, 0.0001)
	assert_almost_eq(BuildingRubbleEdge2D.HOLE_HALF_EXTENTS.y, 0.38, 0.0001)
	assert_eq(edge.cutout_parameter(&"ground_open"), 1.0)
	var texture_size: Vector2 = intact_sprite.texture.get_size()
	assert_eq(
		edge.cutout_parameter(&"atlas_region_uv"),
		Vector4(
			intact_sprite.region_rect.position.x / texture_size.x,
			intact_sprite.region_rect.position.y / texture_size.y,
			intact_sprite.region_rect.size.x / texture_size.x,
			intact_sprite.region_rect.size.y / texture_size.y
		)
	)
	assert_null(edge.get_node_or_null(^"DestroyedInterior"))
	var cutout_material: ShaderMaterial = hollow_facade.material as ShaderMaterial
	assert_not_null(cutout_material)
	assert_not_null(cutout_material.shader)
	assert_true(cutout_material.shader.code.contains("discard"))
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


func test_chunk_progression_scales_enemy_and_hazard_pressure_inside_caps() -> void:
	var city: CitySlice = await _spawn_city()
	await _move_to_logical_chunk(city, 24)
	assert_eq(city.world_stream.progression_tier(), 3)
	var director: DistrictResponseDirector = city.urban_siege.director
	var act: DistrictAct = city.urban_siege.district.acts[3]
	var beat: DistrictBeat = act.beats[0]
	var base_copies: Dictionary[int, int] = director._progression_copy_plan(beat, 0)
	var scaled_copies: Dictionary[int, int] = director._progression_copy_plan(beat, 3)
	assert_eq(base_copies.size(), 0)
	assert_eq(scaled_copies.size(), mini(3, beat.spawns.size()))
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
		0
	)
	var base_budget: int = controller.last_used_budget
	controller.configure(4401, 1)
	var scaled_hazards: Array[Dictionary] = controller.plan_for_beat(
		3,
		0,
		act,
		beat,
		city.robot.global_position.x,
		3
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
	director._try_start_next_beat()
	var authored_count: int = 0
	for entry: EnemySpawnEntry in beat.spawns:
		authored_count += EnemyArchetypeCatalog.spawn_multiplier(StringName(entry.kind))
	assert_eq(
		director._beat_pending.size(),
		authored_count + mini(3, beat.spawns.size())
	)
	assert_eq(director.progression_peak_tier, 3)
	assert_lte(director._hazard_pending.size(), RuntimeBudget.PENDING_HAZARDS)
	_record_test_execution()


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	return city


func _move_to_logical_chunk(city: CitySlice, logical_index: int) -> void:
	city.robot.global_position.x = city.world_stream.runtime_x_for_logical_index(logical_index) + 700.0
	city.world_stream.advance_stream()
	await get_tree().physics_frame
	city.world_stream.advance_stream()
	await get_tree().process_frame


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


func _record_test_execution() -> void:
	if OS.has_environment("MGS_TEST_LOG"):
		var file: FileAccess = FileAccess.open(
			OS.get_environment("MGS_TEST_LOG"),
			FileAccess.WRITE_READ
		)
		if file != null:
			file.seek_end()
			file.store_line("test_endless_destructible_city")

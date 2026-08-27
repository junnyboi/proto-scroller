extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EPSILON: float = 0.5


func test_six_chunk_window_reuses_fixed_nodes_across_long_forward_travel() -> void:
	var city: CitySlice = await _spawn_city()
	var baseline_nodes: int = RuntimeBudget.snapshot(city).node_count
	assert_eq(CityWorldStream.LEFT_RETENTION_DISTANCE, 1000.0)
	assert_eq(city.world_stream.active_chunk_count(), CityWorldStream.CHUNK_CAPACITY)
	for logical_index: int in range(0, 49):
		_move_to_logical_chunk(city, logical_index)
		_assert_contiguous_window(city.world_stream)
	assert_eq(RuntimeBudget.snapshot(city).node_count, baseline_nodes)
	assert_eq(city.world_stream.post_warm_creation_count, 0)
	assert_gte(city.world_stream.floating_origin.shift_count, 2)
	assert_eq(city.world_stream.minimum_visited_chunk, 0)
	assert_eq(city.world_stream.maximum_visited_chunk, 48)
	assert_almost_eq(
		city.world_stream.rear_frontier_logical_x,
		city.world_stream.furthest_progress_logical_x
		- CityWorldStream.LEFT_RETENTION_DISTANCE,
		EPSILON
	)
	var rear_contacts: Array[int] = [0]
	city.world_stream.rear_barrier_contact.connect(func() -> void:
		rear_contacts[0] += 1
	)
	var attempted_left_x: float = city.world_stream.rear_frontier_runtime_x() - 900.0
	city.robot.global_position.x = attempted_left_x
	city.world_stream.advance_stream()
	assert_eq(rear_contacts[0], 1)
	assert_true(city.gameplay_hud.rear_barrier_warning.visible)
	assert_eq(city.gameplay_hud.rear_barrier_warning_play_count, 1)
	assert_eq(city.gameplay_hud.rear_barrier_warning_audio.bus, &"Voice")
	assert_eq(
		city.gameplay_hud.rear_barrier_warning_audio.stream.resource_path,
		"res://audio/voice/rear_barrier_warning.wav"
	)
	assert_gte(
		city.robot.global_position.x,
		city.world_stream.rear_frontier_runtime_x()
		+ CityWorldStream.ROBOT_BARRIER_CLEARANCE
	)
	city.robot.global_position.x = attempted_left_x
	city.world_stream.advance_stream()
	assert_eq(rear_contacts[0], 1)
	assert_eq(city.gameplay_hud.rear_barrier_warning_play_count, 1)
	city.robot.global_position.x += 100.0
	city.world_stream.advance_stream()
	city.robot.global_position.x = (
		city.world_stream.rear_frontier_runtime_x()
		+ CityWorldStream.ROBOT_BARRIER_CLEARANCE
	)
	Input.action_press(&"move_left")
	city.world_stream.advance_stream()
	Input.action_release(&"move_left")
	assert_eq(rear_contacts[0], 2)
	assert_eq(city.gameplay_hud.rear_barrier_warning_play_count, 2)
	city.gameplay_hud._process(GameplayHud.REAR_BARRIER_WARNING_DURATION + 0.01)
	assert_false(city.gameplay_hud.rear_barrier_warning.visible)
	for chunk: CityStreetChunk in city.world_stream.chunks:
		if (
			float(chunk.logical_index + 1) * CityWorldStream.CHUNK_WIDTH
			+ CityWorldStream.CHUNK_CONTENT_OVERHANG
			<= city.world_stream.rear_frontier_logical_x
		):
			assert_true(chunk.culled)
	_record_test_execution()


func test_rear_frontier_collision_is_player_only() -> void:
	var city: CitySlice = await _spawn_city()
	var stream: CityWorldStream = city.world_stream
	assert_eq(CityWorldStream.LEFT_RETENTION_DISTANCE, 1000.0)
	assert_almost_eq(
		stream.rear_frontier_logical_x,
		stream.furthest_progress_logical_x - 1000.0,
		EPSILON
	)
	assert_eq(stream.rear_barrier.collision_layer, CityWorldStream.REAR_BARRIER_LAYER)
	assert_eq(stream.rear_barrier.collision_mask, CityStreetChunk.ROBOT_LAYER)
	assert_ne(city.robot.collision_mask & CityWorldStream.REAR_BARRIER_LAYER, 0)
	for actor: EnemyActor2D in city.encounter_runtime.all_actors():
		assert_eq(actor.collision_mask & CityWorldStream.REAR_BARRIER_LAYER, 0)
	assert_eq(city.car.collision_mask & CityWorldStream.REAR_BARRIER_LAYER, 0)
	assert_eq(city.streetlamp.collision_mask & CityWorldStream.REAR_BARRIER_LAYER, 0)
	var passer: CharacterBody2D = CharacterBody2D.new()
	passer.name = "RearBarrierNonPlayerProbe"
	passer.collision_layer = CityStreetChunk.ENEMY_LAYER
	passer.collision_mask = CityStreetChunk.WORLD_LAYER
	passer.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(32.0, 32.0)
	shape_node.shape = shape
	passer.add_child(shape_node)
	city.add_child(passer)
	passer.global_position = Vector2(stream.rear_frontier_runtime_x() + 96.0, 180.0)
	await get_tree().physics_frame
	for _step: int in range(12):
		passer.velocity = Vector2(-1200.0, 0.0)
		passer.move_and_slide()
		await get_tree().physics_frame
	assert_lt(passer.global_position.x, stream.rear_frontier_runtime_x() - 40.0)
	_record_test_execution()


func test_blueprints_are_seeded_by_run_and_logical_chunk_not_pool_slot() -> void:
	var first: CityChunkBlueprint = CityChunkBlueprint.generate(7331, 19)
	var repeated: CityChunkBlueprint = CityChunkBlueprint.generate(7331, 19)
	var neighbor: CityChunkBlueprint = CityChunkBlueprint.generate(7331, 20)
	assert_eq(first.generation_seed, repeated.generation_seed)
	assert_eq(first.lane_phase, repeated.lane_phase)
	assert_eq(first.asphalt_color, repeated.asphalt_color)
	assert_ne(first.generation_seed, neighbor.generation_seed)
	_record_test_execution()


func test_five_unique_buildings_unlock_the_next_district_once() -> void:
	var city: CitySlice = await _spawn_city()
	var stream: CityWorldStream = city.world_stream
	var business: CityDistrictProfile = CityDistrictCatalog.districts()[0]
	assert_eq(stream.unlocked_district_index, 0)
	assert_false(stream.district_exit_is_unlocked(0))
	for index: int in range(business.building_variants.size()):
		var variant: StructuralBuildingVariant = business.building_variants[index]
		var building: StructuralBuilding2D = StructuralBuilding2D.new()
		building.set_meta(&"district_id", business.district_id)
		building.set_meta(&"district_index", business.district_index)
		building.set_meta(&"building_variant_id", variant.variant_id)
		assert_true(stream.report_building_cleared(building))
		assert_false(stream.report_building_cleared(building))
		building.free()
		assert_eq(stream.district_clear_count(business.district_id), index + 1)
		assert_almost_eq(
			stream.district_exit_barrier.position.x,
			float(index + 2) * CityWorldStream.CHUNK_WIDTH,
			EPSILON
		)
	assert_true(stream.district_exit_is_unlocked(0))
	assert_eq(stream.unlocked_district_index, 1)
	assert_almost_eq(
		stream.district_exit_barrier.position.x,
		float(CityDistrictCatalog.CHUNKS_PER_DISTRICT + 1)
		* CityWorldStream.CHUNK_WIDTH,
		EPSILON
	)
	_record_test_execution()


func test_culled_chunk_restores_original_collision_layers_when_reused() -> void:
	var chunk: CityStreetChunk = CityStreetChunk.new()
	add_child_autofree(chunk)
	await get_tree().process_frame
	var original_layer: int = chunk.ground.collision_layer
	var original_mask: int = chunk.ground.collision_mask
	chunk.set_culled(true)
	assert_true(chunk.culled)
	assert_false(chunk.visible)
	assert_eq(chunk.ground.collision_layer, 0)
	assert_eq(chunk.ground.collision_mask, 0)
	chunk.set_culled(false)
	assert_false(chunk.culled)
	assert_true(chunk.visible)
	assert_eq(chunk.ground.collision_layer, original_layer)
	assert_eq(chunk.ground.collision_mask, original_mask)
	_record_test_execution()


func test_robot_crosses_a_streamed_ground_seam_without_falling() -> void:
	var city: CitySlice = await _spawn_city()
	city.robot.set_physics_process(false)
	_move_to_logical_chunk(city, 5)
	city.robot.global_position = Vector2(
		city.world_stream.runtime_x_for_logical_index(5)
		+ CityWorldStream.CHUNK_WIDTH
		- 90.0,
		460.0
	)
	var initial_x: float = city.robot.global_position.x
	var maximum_y: float = city.robot.global_position.y
	for movement_frame: int in range(90):
		await get_tree().physics_frame
		city.robot.physics_step(1.0, 1.0 / 60.0)
		city.world_stream.advance_stream()
		maximum_y = maxf(maximum_y, city.robot.global_position.y)
	assert_gt(city.robot.global_position.x, initial_x + 180.0)
	assert_eq(city.world_stream.current_logical_chunk, 6)
	assert_lt(maximum_y, 530.0)
	_record_test_execution()


func test_floating_origin_preserves_live_relative_positions_and_telegraphs() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	_unlock_districts_through(city.world_stream, 32)
	city.robot.global_position.x = CityWorldStream.CHUNK_WIDTH * 32.0 + 240.0
	var enemy: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		city.robot.global_position + Vector2(420.0, 75.0)
	)
	assert_not_null(enemy)
	var began: bool = enemy.begin_telegraph(
		&"bullet",
		0.8,
		enemy.global_position,
		city.robot.global_position
	)
	assert_true(began)
	var relative_before: Vector2 = enemy.global_position - city.robot.global_position
	var record_before: Dictionary = city.telegraph_presenter.snapshot(enemy._telegraph_id)
	var target_delta_before: Vector2 = (
		(record_before.target as Vector2) - city.robot.global_position
	)
	city.world_stream.advance_stream()
	var record_after: Dictionary = city.telegraph_presenter.snapshot(enemy._telegraph_id)
	assert_eq(city.world_stream.floating_origin.origin_chunk, 32)
	assert_almost_eq(city.robot.global_position.x, 240.0, EPSILON)
	assert_almost_eq(
		(enemy.global_position - city.robot.global_position).x,
		relative_before.x,
		EPSILON
	)
	assert_almost_eq(
		((record_after.target as Vector2) - city.robot.global_position).x,
		target_delta_before.x,
		EPSILON
	)
	var far_band: Parallax2D = city.get_node(^"ParallaxCity/FarSkyline") as Parallax2D
	assert_almost_eq(
		fposmod(far_band.scroll_offset.x, 1344.0),
		fposmod(-CityWorldStream.CHUNK_WIDTH * 32.0 * 0.18, 1344.0),
		EPSILON
	)
	_record_test_execution()


func test_camera_and_enemy_spawns_follow_player_beyond_former_map_edge() -> void:
	var city: CitySlice = await _spawn_city()
	_move_to_logical_chunk(city, 10)
	city.camera_rig.follow_speed = 10000.0
	city.camera_rig._physics_process(1.0)
	assert_gt(city.camera_rig.global_position.x, 2560.0)
	var spawn: Vector2 = city.encounter_runtime.resolve_spawn_position(
		Vector2(0.0, 542.5),
		&"AHEAD"
	)
	assert_gt(spawn.x, 12000.0)
	var bounds: Vector2 = city.world_stream.resident_bounds()
	assert_between(spawn.x, bounds.x, bounds.y)
	var final_act: DistrictAct = city.urban_siege.director.district.acts[5]
	var hazard_plan: Array[Dictionary] = city.urban_siege.hazard_pressure.plan_for_beat(
		5,
		0,
		final_act,
		final_act.beats[0],
		city.robot.global_position.x
	)
	assert_gt(hazard_plan.size(), 0)
	for record: Dictionary in hazard_plan:
		var hazard_x: float = (record.position as Vector2).x
		assert_between(
			absf(hazard_x - city.robot.global_position.x),
			HazardPressureController.MINIMUM_DISTANCE - 1.0,
			HazardPressureController.MAXIMUM_DISTANCE + 1.0
		)
	_record_test_execution()


func test_origin_landmarks_are_disabled_outside_the_resident_window() -> void:
	var city: CitySlice = await _spawn_city()
	_move_to_logical_chunk(city, 5)
	assert_false(city.landmark_root.visible)
	assert_eq(city.landmark_root.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_not_null(city.encounter_runtime.structural_target)
	assert_eq(city.encounter_runtime.structural_target, city.building)
	_move_to_logical_chunk(city, 0)
	assert_true(city.landmark_root.visible)
	assert_eq(city.landmark_root.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(city.encounter_runtime.structural_target, city.building)
	_record_test_execution()


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _move_to_logical_chunk(city: CitySlice, logical_index: int) -> void:
	_unlock_districts_through(city.world_stream, logical_index)
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(logical_index)
		+ CityWorldStream.CHUNK_WIDTH * 0.5
	)
	city.world_stream.advance_stream()


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
			var building: StructuralBuilding2D = StructuralBuilding2D.new()
			building.set_meta(&"district_id", district.district_id)
			building.set_meta(&"district_index", district.district_index)
			building.set_meta(&"building_variant_id", variant.variant_id)
			assert_true(stream.report_building_cleared(building))
			building.free()


func _assert_contiguous_window(stream: CityWorldStream) -> void:
	var indices: Array[int] = []
	var positions: Array[float] = []
	for chunk: CityStreetChunk in stream.chunks:
		indices.append(chunk.logical_index)
		positions.append(chunk.position.x)
	indices.sort()
	positions.sort()
	assert_eq(indices.size(), CityWorldStream.CHUNK_CAPACITY)
	for offset: int in range(indices.size()):
		assert_eq(indices[offset], stream.current_logical_chunk - 2 + offset)
		if offset > 0:
			assert_almost_eq(
				positions[offset] - positions[offset - 1],
				CityWorldStream.CHUNK_WIDTH,
				EPSILON
			)


func _record_test_execution() -> void:
	var path: String = "res://artifacts/unit-tests-ran.txt"
	var count: int = 0
	if FileAccess.file_exists(path):
		var input: FileAccess = FileAccess.open(path, FileAccess.READ)
		count = int(input.get_as_text().strip_edges())
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	output.store_string(str(count + 1))
